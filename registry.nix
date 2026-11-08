# Single source of truth for "a service that has a URL".
#
# Declare an entry in the module that owns the service, not here. That keeps the
# port next to the service it belongs to, and means commenting a module out of
# configuration.nix automatically removes its route -- which is precisely the
# failure that left dawarich/netdata/vpn vhosts serving 502s.
#
#   shlam.services.immich.port = config.services.immich.port;
#
# generates:
#
#   services.caddy.virtualHosts."immich.shlambert.top" = {
#     useACMEHost = "shlambert.top";
#     extraConfig = "reverse_proxy localhost:2283\n";
#   };
#
# A service on a different domain overrides both halves of that -- the vhost key
# and the certificate it is served with:
#
#   shlam.services.quantumsurvivors = {
#     host = "zehra.click";
#     acmeHost = "zehra.click";
#   };
{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    types
    mapAttrs'
    mapAttrsToList
    nameValuePair
    filterAttrs
    optionalString
    concatStringsSep
    literalExpression
    ;

  # Deliberately a plain `let` binding, NOT config.shlam.domain. Referencing
  # `config` from inside an option *type* is the classic infinite-recursion
  # trap: option types are forced during manual generation
  # (documentation.nixos.enable defaults to true), outside any config context.
  domain = "shlambert.top";

  # security.acme.certs.<name> from ./acme.nix -- the DNS-01 wildcard. Only the
  # default: a service on another domain points at its own cert.
  acmeHost = "shlambert.top";

  cfg = config.shlam;

  serviceModule =
    { name, config, ... }:
    {
      options = {
        subdomain = mkOption {
          type = types.str;
          default = name;
          description = ''
            Label prepended to the base domain. MUST NOT reference
            config.services.*: the Caddy vhost attribute names derive from it,
            so such a dependency would form a cycle.
          '';
        };

        host = mkOption {
          type = types.str;
          default = "${config.subdomain}.${domain}";
          defaultText = literalExpression ''"''${subdomain}.${domain}"'';
          description = "Bare hostname, used verbatim as the Caddy vhost key. No scheme.";
        };

        acmeHost = mkOption {
          type = types.str;
          default = acmeHost;
          defaultText = literalExpression ''"${acmeHost}"'';
          description = ''
            security.acme.certs.<name> supplying this vhost's certificate. The
            lexical default, not config.shlam.acmeHost, for the same reason as
            `domain` above. An assertion checks that the named cert actually
            covers `host`.
          '';
        };

        url = mkOption {
          type = types.str;
          default = "https://${config.host}";
          defaultText = literalExpression ''"https://''${host}"'';
          description = "Public URL, for modules that need an absolute origin.";
        };

        port = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Localhost port to reverse-proxy to. null = not a simple proxy.";
        };

        upstream = mkOption {
          type = types.nullOr types.str;
          default = if config.port == null then null else "localhost:${toString config.port}";
          defaultText = literalExpression ''"localhost:''${toString port}"'';
          description = ''
            reverse_proxy target. nullOr on purpose: `toString null` is "" in
            Nix, so a plain types.str would silently emit "localhost:".
          '';
        };

        proxy = mkOption {
          type = types.bool;
          default = config.upstream != null;
          defaultText = literalExpression "upstream != null";
          description = ''
            Emit `reverse_proxy <upstream>`. Set false for vhosts whose body is
            supplied by an upstream NixOS module (e.g. freshrss's php_fastcgi).
          '';
        };

        publicPort = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = ''
            Also serve this host on a second HTTPS listener, meant to be the
            target of a router port-forward (WAN 443 -> this port). The :443
            vhost is left alone, so LAN and WAN are separate doors to the same
            service rather than one replacing the other.

            Isolation is the whole point: Caddy gives this port its own server
            whose routing table holds only the hosts that name this port, so a
            service added to the registry later cannot become internet-reachable
            by accident. Several hosts may share one (the router forwards WAN 443
            to a single port), each opting in by naming it. Forwarding WAN 443 ->
            443 would instead publish every vhost at once, since *.${domain}
            already resolves to the WAN IP.
          '';
        };

        publicHttpPort = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = ''
            Plain-HTTP counterpart of publicPort, serving nothing but a redirect
            to https://<host> (WAN 80 -> this port). Worth having so a typed
            "zehra.click" reaches the site at all: browsers that try HTTP first
            would otherwise hang.

            Forwarding WAN 80 -> 80 works too, but Caddy's :80 listener carries
            the automatic redirects for *every* vhost, so it hands out the full
            list of internal hostnames to anyone who asks.
          '';
        };

        vhost = mkOption {
          type = types.bool;
          default = true;
          description = "Create a Caddy virtual host. false = dashboard-only entry.";
        };

        sso = {
          forward = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Put the vhost behind Authelia with Caddy's forward_auth: every
              request is checked against auth.${domain} first, and anyone not
              logged in is sent to its login page. authelia.nix turns this into
              an access rule, so a service is opted in here and nowhere else.

              Only the vhosts are covered. The service must not be reachable
              some other way -- a container port published on 0.0.0.0, say --
              or this is a lock on one door of several.
            '';
          };
          groups = mkOption {
            type = types.listOf types.str;
            default = [ "admins" ];
            description = "Authelia groups let through; a member of any one is enough.";
          };
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Extra Caddyfile directives. Caddy orders directives canonically
            rather than textually, so placement relative to reverse_proxy is
            not significant for distinct directives.
          '';
        };

        dashboard = mkOption {
          default = null;
          description = "homepage-dashboard entry, or null to omit from the dashboard.";
          type = types.nullOr (
            types.submodule {
              options = {
                # `name` is the enclosing service's attribute name, captured
                # lexically. A plain string, not `config` -- no recursion.
                title = mkOption {
                  type = types.str;
                  default = name;
                };
                group = mkOption { type = types.str; };
                shared = mkOption {
                  type = types.bool;
                  default = false;
                  description = ''
                    Also show the tile on the shared dashboard (home.${domain}),
                    the one for everyone, not just admins. Every tile is on the
                    admin dashboard regardless.
                  '';
                };
                icon = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                description = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                order = mkOption {
                  type = types.int;
                  default = 100;
                };
                href = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                extra = mkOption {
                  type = types.attrsOf types.anything;
                  default = { };
                };
              };
            }
          );
        };
      };
    };

  vhostSvcs = filterAttrs (_: s: s.vhost) cfg.services;

  # listToAttrs (which mapAttrs' is built on) keeps the FIRST binding, so two
  # entries resolving to the same host would silently drop one vhost. This
  # assertion is load-bearing, not hardening.
  dupes = filterAttrs (_: owners: builtins.length owners > 1) (
    lib.zipAttrs (mapAttrsToList (n: s: { ${s.host} = n; }) vhostSvcs)
  );

  badUpstream = filterAttrs (_: s: s.proxy && s.upstream == null) cfg.services;

  # "Is this host covered?" is a question about the SAN list of the cert the
  # vhost is actually served with, not about the base domain -- otherwise a
  # second domain could only ever be added by editing this file.
  certs = config.security.acme.certs;

  # A wildcard covers exactly one label, so a.b.shlambert.top under
  # *.shlambert.top would fail the TLS handshake at runtime with no build-time
  # signal.
  matches =
    pattern: h:
    if lib.hasPrefix "*." pattern then
      let
        base = lib.removePrefix "*." pattern;
      in
      lib.hasSuffix ".${base}" h && !(lib.strings.hasInfix "." (lib.removeSuffix ".${base}" h))
    else
      pattern == h;

  covered =
    s:
    let
      cert = certs.${s.acmeHost};
    in
    builtins.any (p: matches p s.host) ([ cert.domain ] ++ cert.extraDomainNames);

  # Split in two so a typo'd cert name reports itself instead of blowing up as
  # a bare "attribute missing" error midway through evaluating `covered`.
  unknownCert = filterAttrs (_: s: !(builtins.hasAttr s.acmeHost certs)) vhostSvcs;
  uncovered = filterAttrs (_: s: builtins.hasAttr s.acmeHost certs && !(covered s)) vhostSvcs;

  publicSvcs = filterAttrs (_: s: s.publicPort != null) vhostSvcs;
  publicHttpSvcs = filterAttrs (_: s: s.publicHttpPort != null) vhostSvcs;

  publicPorts =
    mapAttrsToList (_: s: s.publicPort) publicSvcs
    ++ mapAttrsToList (_: s: s.publicHttpPort) publicHttpSvcs;

  # A forwarded port carries only the hosts that name it -- that IS the isolation
  # property. Several may share one (WAN 443 forwards to a single port), but a port
  # can't be both an HTTPS listener and a plain-HTTP redirect one. 80 and 443 are
  # the shared listeners every other vhost lives on, so naming them here would
  # publish the lot.
  httpsPorts = lib.unique (mapAttrsToList (_: s: s.publicPort) publicSvcs);
  httpPorts = lib.unique (mapAttrsToList (_: s: s.publicHttpPort) publicHttpSvcs);
  dupePorts = builtins.filter (p: builtins.elem p httpPorts) httpsPorts;
  sharedPorts = builtins.filter (p: p == 80 || p == 443) publicPorts;

  # A listener bound to a port some service already answers on fails at bind
  # time, long after the build says yes -- and only for whichever of the two
  # loses the race. qbittorrent's 8080 is the near miss this exists for. Only
  # registry-declared ports are knowable here; anything listening without an
  # entry (loki, the exporters) still has to be checked by hand.
  portOwner =
    p: concatStringsSep ", " (builtins.attrNames (filterAttrs (_: s: s.port == p) cfg.services));
  takenPorts = builtins.filter (p: portOwner p != "") publicPorts;

  # Authelia's authz endpoint, and the identity headers it answers with, passed
  # on to the backend. copy_headers also strips those headers from the client's
  # own request when Authelia doesn't set them, so they cannot be forged.
  forwardAuth = ''
    forward_auth ${cfg.services.auth.upstream} {
      uri /api/authz/forward-auth
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';
  ssoSvcs = filterAttrs (_: s: s.sso.forward) vhostSvcs;

  body =
    s:
    (optionalString s.sso.forward forwardAuth)
    + (optionalString s.proxy "reverse_proxy ${s.upstream}\n")
    + s.extraConfig;

  # --- homepage-dashboard ---------------------------------------------------

  dashSvcs = builtins.filter (s: s.dashboard != null) (builtins.attrValues cfg.services);
  sharedSvcs = builtins.filter (s: s.dashboard.shared) dashSvcs;

  # Groups listed in dashboardGroups come first, in that order; anything else
  # is appended alphabetically rather than silently dropped.
  orderedGroups =
    present:
    builtins.filter (g: builtins.elem g present) cfg.dashboardGroups
    ++ lib.sort (a: b: a < b) (builtins.filter (g: !(builtins.elem g cfg.dashboardGroups)) present);

  cmp =
    a: b:
    if a.dashboard.order != b.dashboard.order then
      a.dashboard.order < b.dashboard.order
    else
      a.dashboard.title < b.dashboard.title;

  mkItem = s: {
    ${s.dashboard.title} =
      (filterAttrs (_: v: v != null) {
        href = if s.dashboard.href != null then s.dashboard.href else s.url;
        inherit (s.dashboard) icon description;
      })
      // s.dashboard.extra;
  };

  # homepage's services.yaml: a list of { <group> = [ <tile> ... ]; }.
  servicesYaml =
    item: svcs:
    let
      byGroup = lib.groupBy (s: s.dashboard.group) svcs;
    in
    map (g: { ${g} = map item (lib.sort cmp byGroup.${g}); }) (orderedGroups (builtins.attrNames byGroup));

  # No widgets on the shared dashboard: they show live data from the admin's
  # point of view -- who is streaming what on Jellyfin, say -- to everyone.
  sharedItem = s: lib.mapAttrs (_: tile: removeAttrs tile [ "widget" ]) (mkItem s);
in
{
  options.shlam = {
    domain = mkOption {
      type = types.str;
      readOnly = true;
      default = domain;
      description = ''
        Base domain. readOnly because the value is baked into the
        shlam.services.<name>.host default, which lives in an option *type* and
        therefore cannot read config. A settable option would be a lie:
        changing it would not change any host.
      '';
    };

    acmeHost = mkOption {
      type = types.str;
      readOnly = true;
      default = acmeHost;
      description = ''
        Default for shlam.services.<name>.acmeHost: the security.acme.certs
        entry holding the *.${domain} wildcard.
      '';
    };

    dashboardGroups = mkOption {
      type = types.listOf types.str;
      default = [
        "Media"
        "File Management"
        "Productivity & Utilities"
        "Media administration"
        "Infrastructure"
      ];
      description = ''
        Dashboard group order. Groups not listed here are appended, sorted
        alphabetically, so a typo in a group name shows up as a stray section
        rather than a missing tile.
      '';
    };

    sharedDashboardServices = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      internal = true;
      readOnly = true;
      description = ''
        services.yaml for the shared dashboard (see ./homepage.nix): the tiles
        with dashboard.shared set, without their widgets.
      '';
    };

    services = mkOption {
      type = types.attrsOf (types.submodule serviceModule);
      default = { };
      description = "The service registry: ports, hostnames and dashboard metadata.";
    };
  };

  config = {
    assertions = [
      {
        assertion = dupes == { };
        message =
          "shlam.services: several entries resolve to the same host: "
          + concatStringsSep "; " (
            mapAttrsToList (h: owners: "${h} <- ${concatStringsSep ", " owners}") dupes
          );
      }
      {
        assertion = badUpstream == { };
        message =
          "shlam.services: proxy = true but neither port nor upstream is set for: "
          + concatStringsSep ", " (builtins.attrNames badUpstream);
      }
      {
        assertion = unknownCert == { };
        message =
          "shlam.services: acmeHost names no security.acme.certs entry (see ./acme.nix): "
          + concatStringsSep ", " (mapAttrsToList (n: s: "${n} (${s.acmeHost})") unknownCert);
      }
      {
        assertion = uncovered == { };
        message =
          "shlam.services: hosts not covered by the certificate they are served with: "
          + concatStringsSep ", " (
            mapAttrsToList (n: s: "${n} (${s.host} vs. cert ${s.acmeHost})") uncovered
          );
      }
      {
        assertion = dupePorts == [ ];
        message =
          "shlam.services: a port can't be both a publicPort and a publicHttpPort: "
          + concatStringsSep ", " (map toString dupePorts);
      }
      {
        assertion = takenPorts == [ ];
        message =
          "shlam.services: publicPort/publicHttpPort already in use as a service port: "
          + concatStringsSep ", " (map (p: "${toString p} (${portOwner p})") takenPorts);
      }
      {
        # Without it, forward_auth would point at nothing and every request
        # would fail -- closed, but with a baffling 502.
        assertion = ssoSvcs == { } || (cfg.services ? auth && config.services.authelia.instances ? main);
        message =
          "shlam.services: sso.forward is set but authelia.nix is not imported: "
          + concatStringsSep ", " (builtins.attrNames ssoSvcs);
      }
      {
        assertion = sharedPorts == [ ];
        message =
          "shlam.services: publicPort/publicHttpPort cannot be 80 or 443 -- those are the "
          + "shared listeners carrying every other vhost.";
      }
    ];

    # Only the forwarded ports; the router decides what actually reaches them.
    networking.firewall.allowedTCPPorts = lib.unique publicPorts;

    services.caddy.virtualHosts =
      mapAttrs' (
        _: s:
        nameValuePair s.host {
          useACMEHost = s.acmeHost;
          extraConfig = body s;
        }
      ) vhostSvcs
      # Same site, second listener. Caddy keys servers by listen address, so
      # this one's routing table contains exactly the hosts that name the port.
      // mapAttrs' (
        _: s:
        nameValuePair "https://${s.host}:${toString s.publicPort}" {
          useACMEHost = s.acmeHost;
          extraConfig = body s;
        }
      ) publicSvcs
      # No useACMEHost: an http:// address is served without TLS, and this
      # listener does nothing but bounce to the canonical https://<host>.
      // mapAttrs' (
        _: s:
        nameValuePair "http://${s.host}:${toString s.publicHttpPort}" {
          extraConfig = "redir https://{host}{uri} permanent\n";
        }
      ) publicHttpSvcs;

    # This option merges by CONCATENATION, not replacement -- any hand-written
    # list left in homepage.nix would render alongside this one, every group
    # appearing twice.
    services.homepage-dashboard.services = servicesYaml mkItem dashSvcs;
    shlam.sharedDashboardServices = servicesYaml sharedItem sharedSvcs;
  };
}
