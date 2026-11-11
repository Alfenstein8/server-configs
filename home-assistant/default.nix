{ config, pkgs, ... }:
# Setup -- pairing the plug, pasting the Energi Fyn token, switching the
# scheduler on -- is in ./README.md. This file is only the declarative half.
let
  port = 8123;

  # The Ledvance plug's switch entity. It cannot be derived here: Tuya Local
  # names entities after the name given to the device when it is added through
  # the config flow, which happens long after this file is evaluated. Set it to
  # whatever the plug ends up being called, then rebuild.
  #
  # Nothing breaks while it is wrong -- input_boolean.cheap_power_scheduler
  # starts off and the automation is gated on it, so the first switch call only
  # happens once the scheduler is deliberately turned on.
  plug = "switch.ledvance_plug";

  # How many hours a day the plug may run. A helper rather than a constant so
  # it can be changed from the dashboard; unset it reads as 0, which means the
  # automation leaves the plug alone until a number is picked.
  hours = "input_number.cheap_power_hours";

  # Built against Home Assistant's own Python, the way nixpkgs builds
  # pkgs.home-assistant-custom-components -- the interpreter has to match the
  # one the service runs under. The package renamed that passthru from
  # `python` to `python3Packages` mid-2026, so both spellings are tried: the
  # flake lock currently sits on the older one.
  haPython = pkgs.home-assistant.python3Packages or pkgs.home-assistant.python.pkgs;
  energi-fyn = haPython.callPackage ./energi-fyn.nix { };
  energidataservice = haPython.callPackage ./energidataservice { };

  # Today's prices as `forecast`, a list of {hour, price} with hour the local
  # hour of day (0-23) and price what ranks it: spot price plus the grid
  # company's time-of-day tariff. Taxes, VAT and the supplier's markup are flat
  # per kWh or a percentage, so they cannot change which hour is cheapest and
  # it does not matter whether a source includes them.
  #
  # Energi Fyn first: it is the household's own price, so nothing about it can
  # be configured wrong. Its `price_forecast` is [{hour, price, tarifPrice,
  # total}], `total` being spot + tariff. But it runs on a token borrowed from
  # the browser, and when that dies the sensor goes unavailable.
  #
  # Energi Data Service is then the fallback: Energinet's open API, no login.
  # Its `raw_today` is [{hour: <start time>, price}] with the tariff already
  # added -- provided its options have hourly resolution and "automatically
  # fetch tariff data" on, with the right grid company (see ./README.md).
  #
  # Neither one populated leaves `forecast` empty, which the templates below
  # read as "false" instead of erroring.
  prices = ''
    {% set rows = namespace(list=[]) %}
    {% set fyn = integration_entities('energi_fyn')
         | select('search', '_current_price$') | list | first | default("") %}
    {% for p in (state_attr(fyn, 'price_forecast') if fyn else none) or [] %}
      {% set rows.list = rows.list
           + [{'hour': (p.hour | as_datetime).hour, 'price': p.total | float}] %}
    {% endfor %}
    {% if not rows.list %}
      {% set eds = expand(integration_entities('energidataservice'))
           | selectattr('attributes.raw_today', 'defined')
           | selectattr('attributes.raw_today')
           | map(attribute='attributes.raw_today') | first | default([]) %}
      {% for p in eds %}
        {% set rows.list = rows.list
             + [{'hour': (p.hour | as_datetime | as_local).hour, 'price': p.price | float}] %}
      {% endfor %}
    {% endif %}
    {% set forecast = rows.list %}
    {% set wanted = states('${hours}') | int(0) %}
  '';

  # `unique` because the day the clocks go back has two 02:00 rows.
  cheapestHours = ''
    (forecast | sort(attribute='price'))[:wanted] | map(attribute='hour') | unique | list
  '';
in
{
  services.home-assistant = {
    enable = true;

    # Under /mnt/storage/data so restic picks it up -- backup.nix backs up that
    # path and nothing else, and the registry, the plug pairing and the Energi
    # Fyn token all live in .storage rather than in this repo.
    configDir = "/mnt/storage/data/home-assistant";

    # Replaces the module's default list wholesale, so default_config has to be
    # named again: it is what pulls in onboarding, the energy dashboard,
    # zeroconf and the rest of the out-of-the-box set.
    extraComponents = [
      "default_config"
      "met"

      # Not configured anywhere -- carried so a Nord Pool entry (area DK2: the
      # addresses are on Zealand) can be added from the UI without a rebuild,
      # if both price integrations below fail. See ./README.md.
      "nordpool"

      # /api/prometheus, configured below.
      "prometheus"
    ];

    customComponents = [
      # Local control of the Ledvance plug. It speaks Tuya firmware, and this
      # talks to it over the LAN instead of through Tuya's cloud.
      pkgs.home-assistant-custom-components.tuya_local
      # Prices: Energi Fyn, with Energi Data Service as the fallback for when
      # Energi Fyn's token dies. See `prices` above.
      energi-fyn
      energidataservice
    ];

    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        temperature_unit = "C";
        currency = "DKK";
        country = "DK";
        internal_url = config.shlam.services.home-assistant.url;
        # time_zone follows config.time.timeZone on its own.
      };

      default_config = { };

      # Entity states as Prometheus metrics, scraped by prometheus.nix: the
      # plug, power and the electricity price next to the server's own graphs,
      # kept as long as Prometheus keeps anything. Without requires_auth the
      # scrape needs no long-lived token; the vhost below refuses the path, so
      # only loopback reaches it.
      prometheus.requires_auth = false;

      # No `http:` key. Home Assistant reached only through Caddy should bind
      # loopback and trust the forwarded address from there (server_host and
      # trusted_proxies 127.0.0.1 / ::1, use_x_forwarded_for on) -- but those
      # settings now live in .storage and are edited under Settings > System >
      # Network. Home Assistant migrated the old YAML block there and ignores
      # it afterwards; from 2027.2 it stops working altogether.

      # A plain `automation:` key would take the visual editor away: Home
      # Assistant only edits automations it can write back, and it cannot write
      # into the /nix/store. Splitting the key leaves automations.yaml to the UI
      # and keeps the one below declarative. Same for scripts and scenes, which
      # have no declarative half here but would otherwise not load at all.
      "automation ui" = "!include automations.yaml";
      "script ui" = "!include scripts.yaml";
      "scene ui" = "!include scenes.yaml";

      "automation manual" = [
        {
          id = "cheap_power_plug";
          alias = "Plug follows the cheap hours";
          description = ''
            Holds ${plug} on through the cheapest hours of the day and off the
            rest of the time. How many hours comes from ${hours}; the whole
            thing only runs while input_boolean.cheap_power_scheduler is on.
          '';
          mode = "single";
          triggers = [
            {
              trigger = "state";
              entity_id = "binary_sensor.cheap_electricity_now";
              to = [
                "on"
                "off"
              ];
            }
            {
              trigger = "state";
              entity_id = "input_boolean.cheap_power_scheduler";
              to = "on";
            }
            {
              trigger = "homeassistant";
              event = "start";
            }
          ];
          conditions = [
            {
              condition = "state";
              entity_id = "input_boolean.cheap_power_scheduler";
              state = "on";
            }
          ];
          # No `default:` branch on purpose. While the binary sensor is unknown
          # -- no price data yet, or the first seconds after a restart -- the
          # plug is left exactly as it is rather than being switched off on a
          # guess.
          actions = [
            {
              choose = [
                {
                  conditions = [
                    {
                      condition = "state";
                      entity_id = "binary_sensor.cheap_electricity_now";
                      state = "on";
                    }
                  ];
                  sequence = [
                    {
                      action = "switch.turn_on";
                      target.entity_id = plug;
                    }
                  ];
                }
                {
                  conditions = [
                    {
                      condition = "state";
                      entity_id = "binary_sensor.cheap_electricity_now";
                      state = "off";
                    }
                  ];
                  sequence = [
                    {
                      action = "switch.turn_off";
                      target.entity_id = plug;
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];

      # Templates mentioning now() are re-rendered at the top of every minute,
      # so this follows the clock without a trigger of its own.
      template = [
        {
          binary_sensor = [
            {
              name = "Cheap electricity now";
              unique_id = "cheap_electricity_now";
              icon = "mdi:cash-clock";
              state = ''
                ${prices}
                {% if forecast and wanted > 0 %}
                  {{ now().hour in (${cheapestHours}) }}
                {% else %}
                  false
                {% endif %}
              '';
              # now() only to be re-rendered every minute like the state is.
              # Without it this tracks just the entities its last render
              # read, so a render while the integration was gone (no price
              # entity, nothing to watch) left it blank until a reload.
              attributes.cheapest_hours = ''
                {%- set _minute = now().minute %}
                ${prices}
                {% if forecast and wanted > 0 %}
                  {{ ${cheapestHours} | sort | map('string') | join(', ') }}
                {% endif %}
              '';
            }
          ];
        }
      ];

      input_boolean.cheap_power_scheduler = {
        name = "Cheap-power scheduler";
        icon = "mdi:transmission-tower";
      };

      # No `initial`: that would reset the value on every restart. Unset it
      # reads as 0 hours, so the plug is simply never switched on until a
      # number is picked in the UI.
      input_number.cheap_power_hours = {
        name = "Cheap hours per day";
        icon = "mdi:clock-outline";
        min = 0;
        max = 24;
        step = 1;
        mode = "box";
        unit_of_measurement = "h";
      };
    };
  };

  # The UI writes automations, scripts and scenes into these files, but the
  # !include above is evaluated at startup -- a missing file fails the whole
  # config, and an empty one fails its schema. Seeded once, then left alone.
  systemd.services.home-assistant.preStart =
    let
      dir = config.services.home-assistant.configDir;
    in
    ''
      [ -e "${dir}/automations.yaml" ] || echo "[]" > "${dir}/automations.yaml"
      [ -e "${dir}/scenes.yaml" ]      || echo "[]" > "${dir}/scenes.yaml"
      [ -e "${dir}/scripts.yaml" ]     || echo "{}" > "${dir}/scripts.yaml"
    '';

  # tinytuya's discovery listener, which is how the Tuya Local config flow fills
  # in the plug's IP address by itself. Only LAN broadcasts ever arrive here,
  # and controlling the plug afterwards is an outbound TCP connection to its
  # port 6668, needing no rule at all -- so if you would rather type the plug's
  # IP by hand, these three can go.
  networking.firewall.allowedUDPPorts = [
    6666
    6667
    7000
  ];

  shlam.services.home-assistant = {
    subdomain = "ha";
    inherit port;
    # The metrics endpoint is unauthenticated (prometheus.requires_auth above).
    extraConfig = "respond /api/prometheus* 404";
    dashboard = {
      title = "Home Assistant";
      group = "Productivity & Utilities";
      shared = true;
      order = 45;
      icon = "home-assistant.svg";
      description = "Home Automation";
    };
  };
}
