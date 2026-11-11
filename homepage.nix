{
  config,
  lib,
  pkgs,
  ...
}:
# Two dashboards:
#   admin.shlambert.top  every tile, with widgets; behind Authelia (admins).
#     The NixOS module's own instance.
#   home.shlambert.top   only the tiles with dashboard.shared set, for anyone
#     who uses the services; no widgets, no secrets. A second unit built from
#     the module's, below.
let
  adminPort = 8082;
  homePort = 8085;

  yaml = pkgs.formats.yaml { };

  base = config.systemd.services.homepage-dashboard;

  homeWidgets = [
    {
      datetime = {
        text_size = "xl";
        format = {
          dateStyle = "long";
          timeStyle = "short";
          hourCycle = "h23";
        };
      };
    }
  ];

  # Start typing anywhere on the page to filter the tiles by name or
  # description; Enter opens the top match. With no match it offers a
  # DuckDuckGo search. No suggestions: those would send every keystroke from
  # the server to DuckDuckGo.
  quicklaunch = {
    searchDescriptions = true;
    provider = "duckduckgo";
    showSearchSuggestions = false;
  };

  # homepage copies its skeleton into a config directory that lacks a file,
  # and /etc is read-only, so every file it looks for has to exist.
  homeFiles = {
    "services.yaml" = config.shlam.sharedDashboardServices;
    "widgets.yaml" = homeWidgets;
    "settings.yaml" = {
      title = "shlambert";
      inherit quicklaunch;
      # Light mode's dark text doesn't read over the photo. A fixed theme also
      # overrides a mode the browser saved earlier and hides the toggle.
      theme = "dark";
      # Served by Caddy, below: homepage only serves images from its own
      # public/ directory, which is in the read-only store.
      # brightness and saturate are Tailwind steps; anything else (60, say) is
      # silently ignored: 0, 50, 75, 90, 95, 100, 105, 110, 125, 150, 200.
      background = {
        image = "/background.jpg";
        blur = "md";
        brightness = 50;
      };
      cardBlur = "md";
    };
    "bookmarks.yaml" = [ ];
    "docker.yaml" = { };
    "kubernetes.yaml" = { };
    "proxmox.yaml" = { };
  };
in
{
  # The admin service list is generated from shlam.services.<name>.dashboard by
  # ./registry.nix -- each service carries its own tile. Do not add a services
  # list here: the option merges by concatenation, so a second list would show
  # up as duplicate groups rather than as an error.
  services.homepage-dashboard = {
    enable = true;
    listenPort = adminPort;
    allowedHosts = config.shlam.services.admin.host;
    # Widget credentials -- see the homepage entry in ./secrets.nix.
    environmentFiles = [ config.age.secrets.homepage.path ];
    settings = {
      title = "shlambert admin";
      inherit quicklaunch;
    };

    # The info bar along the top. The unit is ProtectSystem=strict, which makes
    # the filesystem read-only but leaves it visible, so statfs on the pool
    # still works.
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          cputemp = true;
          uptime = true;
        };
      }
      {
        resources = {
          label = "System";
          disk = "/";
        };
      }
      {
        resources = {
          label = "Storage";
          disk = "/mnt/storage";
        };
      }
    ]
    ++ homeWidgets;
  };

  environment.etc =
    lib.mapAttrs' (
      name: value: lib.nameValuePair "homepage-home/${name}" { source = yaml.generate name value; }
    ) homeFiles
    // {
      # The cards are nearly transparent by default, which over a bright photo
      # leaves light text on light grass. Dark theme only (settings.yaml).
      "homepage-home/custom.css".text = ''
        .service-card {
          background-color: rgb(0 0 0 / 0.45);
        }
        .service-card, .service-group-name, #information-widgets {
          text-shadow: 0 1px 3px rgb(0 0 0 / 0.8);
        }
      '';
      "homepage-home/custom.js".text = "";
    };

  # The module's unit with its own config, cache and state directories and
  # port. Same hardening; no EnvironmentFile, since there are no widgets.
  systemd.services.homepage-home = {
    description = "Homepage Dashboard (shared)";
    inherit (base) after wantedBy preStart;
    environment = base.environment // {
      HOMEPAGE_CONFIG_DIR = "/etc/homepage-home";
      NIXPKGS_HOMEPAGE_CACHE_DIR = "/var/cache/homepage-home";
      PORT = toString homePort;
      HOMEPAGE_ALLOWED_HOSTS = config.shlam.services.home.host;
    };
    # ExecStartPre is the module's preStart, already inherited above.
    serviceConfig =
      removeAttrs base.serviceConfig [
        "EnvironmentFile"
        "ExecStartPre"
      ]
      // {
        StateDirectory = "homepage-home";
        CacheDirectory = "homepage-home";
        # Only the cpu widget needs all of /proc.
        ProcSubset = "pid";
      };
    restartTriggers = map (n: config.environment.etc."homepage-home/${n}".source) (
      builtins.attrNames homeFiles ++ [ "custom.css" ]
    );
  };

  # No dashboard entries -- the dashboards should not link to themselves.
  shlam.services.admin = {
    port = adminPort;
    sso.forward = true;
  };
  shlam.services.home = {
    port = homePort;
    # handle sorts before reverse_proxy, so this path never reaches homepage.
    # Strip EXIF before replacing the photo: phone pictures carry GPS.
    extraConfig = ''
      handle /background.jpg {
        root * ${./homepage}
        file_server
      }
    '';
  };
}
