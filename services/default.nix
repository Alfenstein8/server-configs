{ pkgs, ... }:
{
  imports = [
    # ./quantumsurvivors.nix
    ./soundmachine.nix
    ./hyggr.nix
    # ./kajak.nix
  ];
}
