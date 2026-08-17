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

  # security.acme.certs.<name> from ./acme.nix -- the DNS-01 wildcard.
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

        vhost = mkOption {
          type = types.bool;
          default = true;
          description = "Create a Caddy virtual host. false = dashboard-only entry.";
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

        # Declared now, consumed later when homepage.nix is migrated. Entries
        # that leave this null cost nothing.
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

  # *.shlambert.top covers exactly one label, so a.b.shlambert.top would fail
  # the TLS handshake at runtime with no build-time signal.
  covered =
    h:
    h == domain
    || (
      lib.hasSuffix ".${domain}" h
      && !(lib.strings.hasInfix "." (lib.removeSuffix ".${domain}" h))
    );
  uncovered = filterAttrs (_: s: !(covered s.host)) vhostSvcs;

  # --- homepage-dashboard ---------------------------------------------------

  dashSvcs = builtins.filter (s: s.dashboard != null) (builtins.attrValues cfg.services);
  byGroup = lib.groupBy (s: s.dashboard.group) dashSvcs;
  present = builtins.attrNames byGroup;

  # Groups listed in dashboardGroups come first, in that order; anything else
  # is appended alphabetically rather than silently dropped.
  ordered =
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
      description = "security.acme.certs.<name> providing the wildcard certificate.";
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
        assertion = uncovered == { };
        message =
          "shlam.services: hosts not covered by the *.${domain} wildcard certificate: "
          + concatStringsSep ", " (mapAttrsToList (n: s: "${n} (${s.host})") uncovered);
      }
    ];

    services.caddy.virtualHosts = mapAttrs' (
      _: s:
      nameValuePair s.host {
        useACMEHost = acmeHost;
        extraConfig = (optionalString s.proxy "reverse_proxy ${s.upstream}\n") + s.extraConfig;
      }
    ) vhostSvcs;

    # This option merges by CONCATENATION, not replacement -- any hand-written
    # list left in homepage.nix would render alongside this one, every group
    # appearing twice.
    services.homepage-dashboard.services = map (g: {
      ${g} = map mkItem (lib.sort cmp byGroup.${g});
    }) ordered;
  };
}
