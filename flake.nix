{
  description = "Home server flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # Only for intel-compute-runtime-legacy1, which stopped building on unstable
    # around 2026-09-29. The i5-8500's UHD 630 (Gen9.5) is too old for the
    # current intel-compute-runtime, and Jellyfin needs one of them for OpenCL
    # tone mapping. Drop this once legacy1 builds on nixpkgs again.
    nixpkgs-legacy1.url = "github:nixos/nixpkgs/e72e4f299401a3689d4b3d5fc6496b11db7064eb";
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
  };

  outputs =
    {
      nixpkgs,
      nvf,
      agenix,
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
            ;
        };
        modules = [
          agenix.nixosModules.default
          nvf.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
