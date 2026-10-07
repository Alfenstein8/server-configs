{ pkgs, ... }:
{
  imports = [
    ./quantumsurvivors.nix
    ./soundmachine.nix
    ./p7.nix
    # ./kajak.nix
  ];
}
