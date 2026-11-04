# ntfy (ntfy.sh): push notifications to the phone, from anything that can make
# an HTTP request. One place for every alert -- Grafana, Uptime Kuma,
# claude-ops -- to land, without tying them to Discord or any other chat app.
# The Android app (F-Droid or Play) subscribes to https://ntfy.shlambert.top
# with the `alfred` login; it keeps its own connection open, no Google needed.
#
# Private: deny-all by default, so nothing reads or writes without a login.
# Users, ACLs and tokens are declared in ../secrets/ntfy.age, an environment
# file (ageGen secrets/ntfy.age). Make the hashes and the token on the server
# with `nix shell nixpkgs#ntfy-sh -c ntfy user hash` (and `... ntfy token
# generate`) -- the file has to exist before the first rebuild, so the CLI this
# module installs isn't there yet. Single quotes, since bcrypt hashes have $s:
#
#   NTFY_AUTH_USERS='alfred:<ntfy user hash>:admin,homeserver:<ntfy user hash>:user'
#   NTFY_AUTH_ACCESS='homeserver:homeserver:wo'
#   NTFY_AUTH_TOKENS='homeserver:<ntfy token generate>:alerts'
#
# `alfred` is the phone (admin: reads every topic). `homeserver` is the senders'
# account: write-only on the `homeserver` topic, used through its token. Its
# password is never used -- hash something random and forget it. Users dropped
# from that list are deleted from the database on the next start.
{ config, ... }:
let
  port = 2586;
in
{
  services.ntfy-sh = {
    enable = true;
    environmentFile = config.age.secrets.ntfy.path;
    settings = {
      base-url = config.shlam.services.ntfy.url;
      # IPv4 loopback, not the module's [::1]: the registry proxies to
      # localhost:<port>, and Caddy may resolve that to 127.0.0.1 first.
      listen-http = "127.0.0.1:${toString port}";
      # Rate limits go by client IP; behind Caddy every request would
      # otherwise come from 127.0.0.1 and share a single bucket.
      behind-proxy = true;
      auth-default-access = "deny-all";
      # The web app's login, for reading and testing from a browser.
      enable-login = true;
      # How far back the web app and `ntfy sub --poll` can see (default 12h).
      # The phone app keeps its own history regardless; this is for the PCs,
      # whose client shows only what arrives while connected.
      cache-duration = "720h";
    };
  };

  # ntfy reads users and tokens only at start, and a changed ntfy.age leaves
  # the unit itself untouched, so nothing would restart it: a new token would
  # get 401 until someone did. The .age file's store path changes with it.
  systemd.services.ntfy-sh.restartTriggers = [ config.age.secrets.ntfy.file ];

  shlam.services.ntfy = {
    inherit port;

    # The phone has to reach it off the Wi-Fi and off the tailnet, so it joins
    # zehra.click, hyggr and the rest on the router's WAN 443 -> 8443 /
    # WAN 80 -> 8880 forward (see services/quantumsurvivors.nix). Needs its own
    # A record at the registrar pointing at the WAN address, since the
    # *.shlambert.top wildcard answers the LAN one.
    publicPort = 8443;
    publicHttpPort = 8880;
    dashboard = {
      title = "ntfy";
      group = "Infrastructure";
      order = 15;
      icon = "ntfy.svg";
      description = "Push Notifications";
    };
  };
}
