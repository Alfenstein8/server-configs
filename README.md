# server-configs

NixOS configuration for `homeserver`. One module per service, switched on and off
from the import list in [`configuration.nix`](configuration.nix).

## Deploying

The server runs this repo from `/etc/nixos`:

```sh
cd /etc/nixos
git pull
sudo nixos-rebuild build  --flake .#homeserver   # eval + build, no activation
sudo nixos-rebuild switch --flake .#homeserver
```

`build` first is worth the extra minute: it catches evaluation errors and the
registry's assertions without touching the running system. If something does go
wrong after `switch`, `sudo nixos-rebuild switch --rollback` backs it out, and
previous generations stay in the boot menu.

Flakes only see **git-tracked** files. A newly added `.nix` module has no effect
until it is at least `git add`-ed.

## Adding a service

Services that have a URL declare it with `shlam.services.<name>`, defined in
[`registry.nix`](registry.nix). That single declaration generates both the Caddy
virtual host and the homepage-dashboard tile. Declare it **in the service's own
module**, never centrally — that way commenting the module out of
`configuration.nix` also removes its route and its tile.

```nix
{ config, ... }:
{
  services.mealie = {
    enable = true;
    port = 8001;
  };

  shlam.services.mealie = {
    subdomain = "menu";                       # defaults to the attribute name
    port = config.services.mealie.port;
    dashboard = {
      title = "Mealie";
      group = "Productivity & Utilities";
      order = 40;
      icon = "mealie.svg";
      description = "Recipes & Meal Planning";
    };
  };
}
```

That produces `https://menu.shlambert.top`, reverse-proxied to `localhost:8001`,
served with the `*.shlambert.top` wildcard certificate, with `:80` redirecting to
`:443`, plus a tile on the dashboard.

Then add the module to `imports` in `configuration.nix`.

### Where the port comes from

Three cases, in order of preference:

1. **The service has a real port option** — read it, so the number is written
   once: `port = config.services.mealie.port;`
2. **The port is a string, or buried in a larger value** — declare it in a `let`
   and write it *into* the service, rather than parsing it back out:

   ```nix
   let port = 8384; in {
     services.syncthing.guiAddress = "0.0.0.0:${toString port}";
     shlam.services.syncthing.port = port;
   }
   ```

   Same for `uptime-kuma` (`settings.PORT` is a string), `restic`
   (`listenAddress` may or may not carry a host part) and anything in a compose
   module, where ports only exist inside `"8080:8080/tcp"` strings.
3. **The module writes an option the registry also reads** — always use the `let`
   form. `forgejo` is the example: its `settings.server` is a freeform attrset
   where `DOMAIN` reads the registry, so reading `HTTP_PORT` back out of the same
   attrset is a shape worth not having.

### Feeding the hostname back

Anything that needs its own public address should take it from the registry
rather than repeating the domain — `config.shlam.services.<name>.host` for a bare
hostname, `.url` for `https://…`:

```nix
services.forgejo.settings.server.ROOT_URL = config.shlam.services.forgejo.url;
services.paperless.domain                = config.shlam.services.paperless.host;
services.cockpit.allowed-origins         = [ config.shlam.services.cockpit.url ];
```

The one rule: **`subdomain` must never depend on `config.services.*`**. Virtual
host attribute names derive from it, so such a dependency forms a cycle.

### Services that are not a simple proxy

Leave `port` unset and the registry emits only the TLS directive, letting another
module supply the site body. `freshrss` is the case — it runs as a php-fpm pool
over a unix socket, and a `reverse_proxy` would shadow the PHP handler:

```nix
services.freshrss.virtualHost = config.shlam.services.freshrss.host;
shlam.services.freshrss.subdomain = "rss";     # no port ⇒ proxy = false
```

Use `vhost = false` for a dashboard tile with no virtual host, and `href` to
point a tile somewhere other than its own URL.

## TLS

[`acme.nix`](acme.nix) obtains one wildcard certificate for `*.shlambert.top` over
DNS-01 (Spaceship). Every virtual host uses it via `useACMEHost`, so Caddy performs
no ACME of its own and `services.caddy.email` / `acmeCA` have no effect.

Two consequences:

- The wildcard covers **exactly one label**. `a.b.shlambert.top` would fail the TLS
  handshake at runtime, so the registry asserts against it at build time.
- A DNS-01 failure degrades every host at once. Caddy still starts — a self-signed
  placeholder is always generated — but nothing will be trusted until
  `acme-shlambert.top.service` succeeds.

Reaching the server by LAN IP fails SNI. Use the hostnames; AdGuard Home resolves
them locally.

## Assertions

`nixos-rebuild build` fails, with the offending names in the message, if:

- two entries resolve to the same host (they would otherwise silently overwrite
  each other, since `listToAttrs` keeps the first binding);
- an entry proxies but has neither `port` nor `upstream`;
- a host falls outside the wildcard's reach;
- a forwarded port (`publicPort`, `publicHttpPort`) is 80 or 443, is already a
  service's port, or is used both for HTTPS and for the HTTP redirect. Several
  hosts may share one (the router forwards WAN 443 to a single port): each must
  name it, so a public listener carries exactly the hosts that opted in
  (`zehra.click` and `hyggr.shlambert.top` on 8443/8880).

## Layout

| | |
|---|---|
| `flake.nix`, `configuration.nix` | entry point and the module on/off list |
| `registry.nix` | `shlam.services.<name>` → Caddy vhost + dashboard tile |
| `caddy.nix` | just `services.caddy.enable`; vhosts live with their services |
| `acme.nix` | the DNS-01 wildcard |
| `secrets.nix`, `secrets/` | agenix; edit with the `ageGen` alias from `bash.nix` |
| `arr/` | Podman stack, one file per container; `default.nix` holds the shared runtime, network and target |
| `tubearchivist/` | Podman stack; `docker-compose.nix` is hand-edited |
| `home-assistant/` | Home Assistant, and the Energi Fyn component it pins; setup lives in its own README |
| `services/` | systemd units for apps run out of `/home/alfred/manual`, and `hyggr.nix`: Hyggr (formerly P7 Events) from its own flake (input `hyggr`), which deploys each new release itself |

Whether a module is enabled is recorded in exactly one place: the `imports` list
in `configuration.nix` (or `services/default.nix`). Modules commented out there
still carry their registry entry, so enabling one is a single uncomment — no
other file needs touching.
