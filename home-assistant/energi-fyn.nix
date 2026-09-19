# https://github.com/LovelessCodes/energi_fyn -- an unofficial integration for
# Energi Fyn's customer API. Not in nixpkgs, and upstream cuts no releases, so
# this pins a commit.
#
# To bump: set `rev` to the new commit and `version` to its date, then run
#   nix-prefetch-github LovelessCodes energi_fyn --rev <rev>
# or just rebuild -- the failing build prints the hash it wanted.
{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  async-timeout,
}:

buildHomeAssistantComponent rec {
  owner = "LovelessCodes";
  domain = "energi_fyn";
  version = "0-unstable-2026-04-01";

  src = fetchFromGitHub {
    inherit owner;
    repo = "energi_fyn";
    rev = "0a859373e5ed8343525a819de8055ce07dfc25d5";
    hash = "sha256-5dRrx0WOCWwW5VtuSwUiUKUzN92976Y3wG+wWy+XvMY=";
  };

  # manifest.json declares no requirements, so the manifest check hook has
  # nothing to complain about -- but coordinator.py does `import async_timeout`,
  # which Home Assistant itself no longer pulls in. Left out, the integration
  # builds fine and then fails to load at runtime, which is the worse of the two
  # failures.
  dependencies = [ async-timeout ];

  meta = {
    description = "Energi Fyn electricity consumption and prices in Home Assistant";
    homepage = "https://github.com/LovelessCodes/energi_fyn";
    license = lib.licenses.mit;
  };
}
