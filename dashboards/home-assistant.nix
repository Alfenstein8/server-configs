# Home Assistant's entity states, from its prometheus integration
# (home-assistant/default.nix). Sensors are named by device class and unit --
# homeassistant_sensor_<class>_<unit>, `/` in a unit spelled _per_ -- so panels
# select by name pattern, and new entities appear without touching this file.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  sensors = pattern: ''{__name__=~"homeassistant_sensor_${pattern}"}'';
in
d.dashboard {
  uid = "home-assistant";
  title = "Home Assistant";
  from = "now-7d";
  panels = [
    (d.stat "Entities" (pos 0 0 6 4) "none" "count(homeassistant_entity_available)")
    (d.alarm "Unavailable" (pos 6 0 6
      4
    ) "none" "count(homeassistant_entity_available == 0) or vector(0)" 1)
    (d.stat "Power now" (pos 12 0 6 4) "watt" "sum(${sensors "power_w"})")
    (d.stat "Price now" (pos 18 0 6 4) "none" "max(${sensors ".*_per_kwh"})")

    (d.panel "state-timeline" "Switches" (pos 0 4 24 6) "none"
      (d.targets [
        [
          "homeassistant_switch_state"
          "{{friendly_name}}"
        ]
      ])
      {
        fieldConfig = {
          defaults.mappings = [
            {
              type = "value";
              options = {
                "1" = {
                  text = "on";
                  color = "green";
                };
                "0" = {
                  text = "off";
                  color = "transparent";
                };
              };
            }
          ];
          overrides = [ ];
        };
        options = {
          showValue = "never";
          mergeValues = true;
          legend.showLegend = false;
        };
      }
    )

    (d.timeseries "Power" (pos 0 10 12 9) "watt" [
      [
        (sensors "power_w")
        "{{friendly_name}}"
      ]
    ])
    # Energi Fyn's price, whatever unit it is reported in (DKK/kWh).
    (d.timeseries "Electricity price" (pos 12 10 12 9) "none" [
      [
        (sensors ".*_per_kwh")
        "{{friendly_name}}"
      ]
    ])
    (d.timeseries "Energy" (pos 0 19 12 9) "kwatth" [
      [
        (sensors "energy_kwh")
        "{{friendly_name}}"
      ]
    ])
    (d.timeseries "Temperature" (pos 12 19 12 9) "celsius" [
      [
        (sensors "temperature_celsius")
        "{{friendly_name}}"
      ]
    ])
  ];
}
