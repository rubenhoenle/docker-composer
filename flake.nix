{
  description = "A flake which builds and serves the mkdocs system for docker-composer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, treefmt-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      build-docs = pkgs.stdenv.mkDerivation {
        name = "mkdocs";
        src = self;
        nativeBuildInputs = with pkgs; [
          python311Packages.mkdocs
          python311Packages.mkdocs-material
        ];
        buildPhase = ''
          mkdocs build --site-dir dist
        '';
        installPhase = ''
          mkdir $out
          cp -R dist/* $out/
        '';
      };

      serve-docs = pkgs.writeShellApplication {
        name = "mkdocs-serve";
        text = ''${(pkgs.python311.withPackages(ps: with ps; [
              mkdocs mkdocs-material
            ]))}/bin/mkdocs serve
        '';
      };
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatter = treefmtEval.config.build.check self;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          jdk17
          python311Packages.mkdocs-material
        ];
        env = {
          JAVA_HOME = "${pkgs.jdk17}";
        };
      };

      packages.${system} = {
        default = serve-docs;
        mkdocs = build-docs;
        serve = serve-docs;
      };
    };
}
