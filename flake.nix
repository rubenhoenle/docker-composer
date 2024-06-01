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

      nginxConf = pkgs.writeText "nginx.conf" ''
         user nginx nginx;
         daemon off;
         error_log /dev/stdout info;
         pid /dev/null;
         events {}
         http {
           access_log /dev/stdout;
           server {
             listen 80;
             index index.html;
             location / {
               root ${build-docs};
             }
             default_type application/octet-stream;
             types {
                text/html                                        html htm shtml;
                text/css                                         css;
                text/xml                                         xml;
                image/gif                                        gif;
                image/jpeg                                       jpeg jpg;
                application/javascript                           js;
                application/atom+xml                             atom;
                application/rss+xml                              rss;

                text/mathml                                      mml;
                text/plain                                       txt;
                text/vnd.sun.j2me.app-descriptor                 jad;
                text/vnd.wap.wml                                 wml;
                text/x-component                                 htc;

                image/avif                                       avif;
                image/png                                        png;
                image/svg+xml                                    svg svgz;
                image/tiff                                       tif tiff;
                image/vnd.wap.wbmp                               wbmp;
                image/webp                                       webp;
                image/x-icon                                     ico;
                image/x-jng                                      jng;
                image/x-ms-bmp                                   bmp;
             }
           }
        }
      '';

      containerImage = pkgs.dockerTools.buildImage {
        name = "ghcr.io/rubenhoenle/docker-composer-docs";
        tag = "unstable";
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ build-docs ];
        };
        extraCommands = ''
          mkdir -p var/log/nginx
          mkdir -p var/cache/nginx
        '';
        runAsRoot = ''
          #!${pkgs.stdenv.shell}
          ${pkgs.dockerTools.shadowSetup}
          groupadd --system nginx
          useradd --system --gid nginx nginx
        '';
        config = {
          Cmd = [ "${pkgs.nginx}/bin/nginx" "-c" nginxConf ];
          ExposedPorts = {
            "80/tcp" = { };
          };
          Labels = {
            "org.opencontainers.image.source" = "https://github.com/rubenhoenle/docker-composer";
            "org.opencontainers.image.description" = "Docker composer html docs";
            "org.opencontainers.image.licenses" = "UNKNOWN";
          };
        };
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
        containerImage = containerImage;
      };
    };
}
