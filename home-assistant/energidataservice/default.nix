# https://github.com/MTrab/energidataservice -- day-ahead spot prices from
# Energinet's open API (Nord Pool as fallback), with the grid company's
# time-of-day tariff added per hour. No account, nothing to log in to.
#
# Not in nixpkgs, and neither are two of its requirements, so they are built
# here as well. To bump: change `version` and `hash` below (a failing build
# prints the hash it wanted), and check manifest.json's `requirements` against
# the versions in the two files next to this one.
{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  callPackage,
  pytz,
}:

buildHomeAssistantComponent rec {
  owner = "MTrab";
  domain = "energidataservice";
  version = "1.6.22";

  src = fetchFromGitHub {
    inherit owner;
    repo = "energidataservice";
    tag = "v${version}";
    hash = "sha256-y2+iDFbt9QOeleNj55lycG1+glGkaMy5tPacsODzrYM=";
  };

  dependencies = [
    (callPackage ./async-retrying-ng.nix { })
    (callPackage ./currencyconverter.nix { })
    # Imported throughout, not declared in manifest.json, and not something
    # Home Assistant pulls in itself.
    pytz
  ];

  meta = {
    description = "Electricity spot prices and tariffs from Energi Data Service";
    homepage = "https://github.com/MTrab/energidataservice";
    changelog = "https://github.com/MTrab/energidataservice/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
  };
}
