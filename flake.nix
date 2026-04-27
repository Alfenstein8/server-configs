{
  description = "Home server flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nvf,
      agenix,
      copyparty,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      hostname = "homeserver";
      nvfNeovim =
        (nvf.lib.neovimConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./nvf.nix ];
        }).neovim;
    in
    {
      packages.${system}.default = nvfNeovim;
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            system
            hostname
            inputs
            nvfNeovim
            copyparty
            ;
        };
        modules = [
          agenix.nixosModules.default
          nvf.nixosModules.default
          copyparty.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
