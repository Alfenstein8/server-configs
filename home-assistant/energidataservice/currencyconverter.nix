# ECB exchange rates, which Energi Data Service uses to turn EUR prices into
# DKK. Not in nixpkgs. The integration uses the rates file bundled in the
# wheel, so they are as old as this version -- harmless here: DKK is pegged to
# EUR, and a constant factor cannot change which hour is cheapest.
{
  lib,
  buildPythonPackage,
  fetchPypi,
}:

buildPythonPackage rec {
  pname = "currencyconverter";
  version = "0.18.22";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    sha256 = "acce36c3868fe863924aa6eb30563b429504056ee8ea1f6a03ce4f2fe33e9a0d";
  };

  pythonImportsCheck = [ "currency_converter" ];

  meta = {
    description = "Currency converter using the European Central Bank data";
    homepage = "https://github.com/alexprengere/currencyconverter";
    license = lib.licenses.asl20;
  };
}
