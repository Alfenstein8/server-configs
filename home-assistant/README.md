# Home Assistant

`ha.shlambert.top`. Runs the Ledvance WiFi plug over the LAN rather than through
Tuya's cloud, reads the household's own electricity price from Energi Fyn (with
Energi Data Service as the fallback), and switches the plug on only during the
cheapest hours of the day.

Four moving parts, each set up once through the web UI, because none of them
can be declared: they all need a credential or an id that only exists after the
fact. What *is* declarative — the integrations themselves, the helpers, the
template and the automation — lives in [`default.nix`](default.nix).

```
Energi Fyn API ──▶ sensor.<address>_current_price
                      │  attribute price_forecast: today, hour by hour,
                      │  spot + transport tariff
                      │
Energinet API ───▶ sensor.energi_data_service       (used only while the
                      │  attribute raw_today: same     Energi Fyn sensor
                      │  thing, tariff added           has no forecast)
                      ▼
            binary_sensor.cheap_electricity_now
                      │  on during the N cheapest hours
                      ▼
            automation "Plug follows the cheap hours"
                      │
                      ▼
            switch.<the plug>  ──(LAN, Tuya protocol)──▶ Ledvance plug
```

## 0. Deploy

The module is already in the `imports` list in
[`configuration.nix`](../configuration.nix), so on the server it is just:

```sh
cd /etc/nixos && git pull
sudo nixos-rebuild switch --flake .#homeserver
```

The first build is a long one: it compiles Home Assistant's dependency set plus
the custom components.

State lives in `/mnt/storage/data/home-assistant`, so restic's `storagebox` job
picks it up — which matters, because the plug's local key and the Energi Fyn
token end up in `.storage` there and nowhere in this repo.

`configuration.yaml` is a read-only symlink into `/nix/store`; editing it does
nothing. Change `default.nix` and rebuild instead. Automations, scripts and
scenes built in the UI are unaffected — they keep their own files next to it,
which is why `default.nix` declares its automation under `automation manual:`
rather than plain `automation:`.

## 1. First run

Open <https://ha.shlambert.top> and create the owner account. Only the hostname
works: the LAN IP fails SNI, and AdGuard Home is what resolves the name at home.

## 2. The Ledvance plug

Ledvance SMART+ WiFi devices are Tuya devices wearing a Ledvance badge. The
`tuya_local` component talks to them directly over the LAN, which needs three
things the plug will not volunteer: its **IP address**, its **device id** and its
**local key**.

### 2a. Pin the IP

Give the plug a DHCP reservation in the router. Discovery can find it on its own
(the UDP ports for that are opened in `default.nix`), but a fixed address
reconnects far faster and does not quietly move.

### 2b. Get the device id and the local key

Two routes. The local key changes **every time the plug is re-paired**, so if you
are going to re-pair, do that first and read the key afterwards.

**Route A — via the SmartLife app.** If the plug can be added to Tuya's own
SmartLife app, Tuya Local's cloud-assisted setup does the rest: it asks for the
*user code* from SmartLife's *Settings → Account and Security*, you scan a QR
code in the app, and it fills in the device id and local key for you. Ledvance
devices are normally paired in the Ledvance app, so this means re-pairing the
plug and losing it from that app.

**Route B — via the Ledvance account.** Keep the plug where it is and read the
key out of Ledvance's own Tuya tenant with
[FlagX/ha-ledvance-tuya-resync-localkey](https://github.com/FlagX/ha-ledvance-tuya-resync-localkey),
which asks for the Ledvance app's username and password and prints every device
with its id and local key:

```sh
git clone https://github.com/FlagX/ha-ledvance-tuya-resync-localkey
cd ha-ledvance-tuya-resync-localkey
nix-shell -p python3 --run '
  python -m venv .venv &&
  .venv/bin/pip install -r requirements.txt &&
  .venv/bin/python print-local-keys.py'
```

[This walkthrough](https://blog.hjf.com.ar/en/2025/01/28/integrating-ledvance-wifi-devices-in-home-assistant/)
covers the same ground, as does the Tuya IoT developer portal route in
[tuya-local's DEVICE_DETAILS.md](https://github.com/make-all/tuya-local/blob/main/DEVICE_DETAILS.md).

### 2c. Add it

*Settings → Devices & services → Add integration → **Tuya Local***, then:

1. **Connection** — the IP from 2a, the device id and local key from 2b, and
   protocol version `auto`. If the plug answers but responds to commands
   unreliably, come back and pin 3.3 or 3.4 by hand.
2. **Device type** — the list is filtered to configs matching what the plug
   actually reported. There is no Ledvance-plug-specific config upstream, so
   expect to pick a generic one: *Smart switch* (`simple_switch`) for a plain
   plug, or one of the power-monitoring socket configs if the plug also reports
   watts. Picking the wrong one means deleting the device and starting over, as
   the entity set is fixed at this point.
3. **Name** — this is what the entity id is built from.

Close the Ledvance app while doing this. Most Tuya devices accept exactly one
local connection, and the phone app holds it.

### 2d. Tell the config which switch it is

Set `plug` at the top of [`default.nix`](default.nix) to the entity id that came
out of step 3 — `switch.…`, copied from *Developer tools → States* — and rebuild.
Until it names a real entity the automation has nothing to switch, which is why
the scheduler in step 4 starts off.

## 3. Energi Fyn

Unofficial, and reading the *Mit Energi Fyn* API means borrowing the session's
refresh token out of the browser:

1. Log in at <https://www.energifyn.dk>.
2. F12 → *Application* → *Session Storage* → the key
   `oidc.user:https://accounts.forsyningslogin.dk:ef-spa`.
3. Copy the `refresh_token` value.
4. *Settings → Devices & services → Add integration → **Energi Fyn*** and paste
   it in.

From there the integration renews its own access token, so this is a one-off
unless the refresh token is revoked — logging out of the portal, or changing the
password, will do that. (Upstream's README still describes an older flow with an
access token that expired after an hour; the commit pinned in
[`energi-fyn.nix`](energi-fyn.nix) is past that.)

Per meter it creates:

| entity | what |
|---|---|
| `sensor.<address>_electricity` | cumulative consumption, kWh |
| `sensor.<address>_current_price` | this hour's price, DKK/kWh, with `price_forecast` — today hour by hour, `price` (spot) + `tarifPrice` (transport) = `total` |

For the energy dashboard: *Settings → Dashboards → Energy → Electricity grid →
Add consumption*, and pick the `_electricity` sensor.

### When the token dies

The refresh token does get revoked — the log then says `Token refresh failed:
400`, the price sensors go unavailable, and Grafana's *Electricity prices
unavailable* alert fires within the hour. Energi Data Service (below) keeps the
plug scheduling meanwhile, so this can wait for a convenient moment.

The integration has no re-authenticate flow, so: *Settings → Devices & services
→ Energi Fyn → ⋮ → Delete*, then *Add entry* with a fresh refresh token from
the steps above. The sensors come back under the same entity ids. Then **close
the portal tab without logging out**: the integration and the browser share
one login session, and logging out ends it for both.

## 3b. Energi Data Service

The fallback price source: Energinet's public day-ahead prices, with the grid
company's tariff added, and no account to log in to. *Settings → Devices &
services → Add integration → **Energi Data Service***:

1. **Country** — Denmark.
2. **Price area** — `DK2`. The addresses are on Zealand, east of the Great
   Belt; Energi Fyn's name notwithstanding, `DK1` is the wrong area.
3. **Show price as an hourly average** — leave it **on**. The template in
   `default.nix` expects one price an hour; 15-minute prices would make it pick
   quarter-hours as if they were hours.
4. VAT, decimals, cent and kWh/MWh can be anything: none of them change which
   hour is cheapest. Leave the additional-costs template empty.
5. **AI forecasts from Carnot** — off. **Automatically fetch tariff data** —
   **on**, and pick the **grid company** (*net operator*): the one named on the
   electricity bill as *netselskab*, not Energi Fyn. Without the tariff it ranks
   on bare spot price, which regularly picks the wrong hours.

Check it once against Energi Fyn while both work: the hours in its sensor's
`raw_today` and in Energi Fyn's `price_forecast` (`total`) should rank the same.

## 4. Switching the plug on the cheap hours

Nothing needs to be built — `default.nix` declares all of it — but it starts
deliberately inert:

| entity | what it does |
|---|---|
| `input_number.cheap_power_hours` | how many hours a day the plug may run. **Unset, which reads as 0**, so set it first. |
| `input_boolean.cheap_power_scheduler` | the master switch. Off until you turn it on. |
| `binary_sensor.cheap_electricity_now` | on during the cheapest `cheap_power_hours` hours of today. Its `cheapest_hours` attribute lists which. |

So: set the number of hours, then turn the scheduler on. The automation *Plug
follows the cheap hours* mirrors the binary sensor onto the plug from there, and
re-evaluates at the top of every minute.

To take the plug back by hand, turn the scheduler off — the plug stays wherever
it happens to be, and nothing touches it again until the scheduler goes back on.

Worth knowing:

- **The ranking is on the delivered price, not the spot price.** The transport
  tariff is time-differentiated, and its daily swing is comparable to the spot
  price's, so ranking by spot alone regularly picks the wrong hours. State
  taxes and VAT are left out on purpose: a flat addition per kWh and a
  percentage cannot change which hour is cheapest.
- **Today only.** Tomorrow's prices are published in the afternoon, but the
  template reads only today's, so the window never crosses midnight. Each
  day is scheduled on its own.
- **The cheap hours are not contiguous.** For a load that has to run in one
  unbroken stretch, this is the wrong shape and wants a "cheapest N-hour block"
  template instead.
- **Check it before trusting it:** *Developer tools → States*,
  `binary_sensor.cheap_electricity_now`, and read `cheapest_hours` against the
  `price_forecast` on the Energi Fyn price sensor.

## If both price sources stop answering

Energi Fyn failing is covered by Energi Data Service. If that fails too, the core
**Nord Pool** integration is already in the package — add it from *Settings →
Devices & services*, area `DK2`, currency `DKK`, no rebuild needed.

It is not a drop-in: Nord Pool serves bare spot prices, without the transport
tariff, and exposes the day's hours through the `nordpool.get_prices_for_date`
action rather than as an entity attribute — so the template in `default.nix`
would have to become an automation that calls that action and compares the
result.

## Bumping the Energi Fyn component

Upstream cuts no releases, so [`energi-fyn.nix`](energi-fyn.nix) pins a commit.
Put the new commit in `rev`, its date in `version`, and let the rebuild tell you
the hash it wanted — or get it up front with:

```sh
nix run nixpkgs#nix-prefetch-github -- LovelessCodes energi_fyn --rev <commit>
```

Worth reading the diff first. It is a young integration against an API nobody
published, and `price_forecast` — the attribute everything here hangs off — is
not a stable interface.

## Bumping Energi Data Service

[`energidataservice/default.nix`](energidataservice/default.nix) pins a release
tag. Change `version`, let the rebuild tell you the hash it wanted, and compare
the new `manifest.json`'s `requirements` with the two dependency files next to
it — neither library is in nixpkgs, so a version bump there means a new wheel
hash too.

`tuya_local` needs none of this; it comes from nixpkgs and follows the flake
lock.
