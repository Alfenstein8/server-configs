{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ... } @ inputs:
  let
    system = "x86_64-linux";
  in
  {

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit system inputs; };
      modules = [
	./configuration.nix
      ];
    };
  };
}
