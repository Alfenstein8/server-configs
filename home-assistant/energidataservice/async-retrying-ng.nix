# Retry decorator for asyncio code, by the Energi Data Service author and used
# only by it. Not in nixpkgs. Pure Python, so the PyPI wheel is taken as-is.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  async-timeout,
}:

buildPythonPackage rec {
  pname = "async-retrying-ng";
  version = "0.1.3";
  format = "wheel";

  src = fetchPypi {
    pname = "async_retrying_ng";
    inherit version format;
    dist = "py3";
    python = "py3";
    sha256 = "59eb82206a8d8237ed21a64012a4a0d8752c0812e81418dad9abe7acc4d60f2a";
  };

  dependencies = [ async-timeout ];
  pythonImportsCheck = [ "async_retrying_ng" ];

  meta = {
    description = "Simple retrying for asyncio";
    homepage = "https://github.com/mtrab/async_retrying_ng";
    license = lib.licenses.mit;
  };
}
