"""Mirror qbit-manage's `private` torrent tag onto Radarr movies and Sonarr series.

A movie or series is tagged `private` exactly when qBittorrent holds a torrent
for it that qbit-manage has tagged `private`; the tag is removed again once no
such torrent is left. The tag is managed: a hand-set `private` tag on anything
else is removed on the next run.

Torrents are matched through the *arr's history, which records each grab with
the torrent's hash as its downloadId. Torrents the *arr never grabbed or
imported (added to qBittorrent by hand) have no history and are skipped.
"""

import http.cookiejar
import json
import os
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

TAG = "private"

QBT_URL = os.environ["QBT_URL"]
QBT_USER = os.environ["QBT_USER"]
QBT_PASS = os.environ["QBIT_PASS"]

# qBittorrent category -> the *arr that grabbed into it.
APPS = {
    "radarr": {
        "url": "http://localhost:7878/api/v3",
        "category": "radarr",
        "media": "movie",
        "history_id": "movieId",
        "editor_ids": "movieIds",
    },
    "sonarr": {
        "url": "http://localhost:8989/api/v3",
        "category": "tv-sonarr",
        "media": "series",
        "history_id": "seriesId",
        "editor_ids": "seriesIds",
    },
}


def private_torrents():
    """Hashes of torrents tagged `private`, grouped by category."""
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
    )
    login = urllib.parse.urlencode({"username": QBT_USER, "password": QBT_PASS})
    with opener.open(f"{QBT_URL}/api/v2/auth/login", login.encode()) as r:
        if r.read().decode().strip() != "Ok.":
            sys.exit("qBittorrent login failed")
    query = urllib.parse.urlencode({"tag": TAG})
    with opener.open(f"{QBT_URL}/api/v2/torrents/info?{query}") as r:
        torrents = json.load(r)
    by_category = {}
    for t in torrents:
        by_category.setdefault(t["category"], set()).add(t["hash"].upper())
    return by_category


def api_key(app):
    path = os.path.join(os.environ["CREDENTIALS_DIRECTORY"], app)
    return ET.parse(path).getroot().findtext("ApiKey")


def call(app, method, path, body=None):
    req = urllib.request.Request(
        APPS[app]["url"] + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"X-Api-Key": api_key(app), "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        raw = r.read()
    return json.loads(raw) if raw else None


def tag_id(app):
    for tag in call(app, "GET", "/tag"):
        if tag["label"] == TAG:
            return tag["id"]
    return call(app, "POST", "/tag", {"label": TAG})["id"]


def sync(app, hashes):
    cfg = APPS[app]
    tid = tag_id(app)

    wanted = set()
    for h in hashes:
        query = urllib.parse.urlencode({"downloadId": h, "pageSize": 50})
        for record in call(app, "GET", f"/history?{query}")["records"]:
            wanted.add(record[cfg["history_id"]])

    items = call(app, "GET", f"/{cfg['media']}")
    existing = {i["id"] for i in items}
    wanted &= existing  # history can outlive a deleted movie/series
    tagged = {i["id"] for i in items if tid in i["tags"]}

    for action, ids in (("add", wanted - tagged), ("remove", tagged - wanted)):
        if ids:
            call(app, "PUT", f"/{cfg['media']}/editor", {
                cfg["editor_ids"]: sorted(ids),
                "tags": [tid],
                "applyTags": action,
            })
    print(
        f"{app}: {len(wanted)} {cfg['media']} with a private torrent, "
        f"+{len(wanted - tagged)} -{len(tagged - wanted)}"
    )


def main():
    torrents = private_torrents()
    for app, cfg in APPS.items():
        sync(app, torrents.get(cfg["category"], set()))


if __name__ == "__main__":
    main()
