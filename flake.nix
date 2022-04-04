{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=master";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    git-ignore-nix.url = "github:hercules-ci/gitignore.nix/master";
    gtk-sni-tray.url = "github:taffybar/gtk-sni-tray/master";
    gtk-strut.url = "github:taffybar/gtk-strut/master";
  };
  outputs = { self, flake-utils, nix-filter, nixpkgs, git-ignore-nix
    , gtk-sni-tray, gtk-strut }:
    let
      overlay = final: prev: {
        haskellPackages = prev.haskellPackages.override (old: {
          overrides = prev.lib.composeExtensions (old.overrides or (_: _: { }))
            (hself: hsuper: {

              taffybar = hself.callCabal2nix "taffybar" (with nix-filter.lib;
                filter {
                  root = git-ignore-nix.lib.gitignoreSource ./.;
                  exclude = [ (matchExt "yaml") (matchExt "yaml.lock") ];
                }) { inherit (final) gtk3; };

              coinbase-pro = prev.haskell.lib.doJailbreak
                (hself.callHackageDirect {
                  pkg = "coinbase-pro";
                  ver = "0.9.2.2";
                  sha256 =
                    "sha256-ZFEcq9aO+72JSVBg0xWi188mz5WK1NTgs6ZGYHtO0OE=";
                } { });

              dyre = prev.haskell.lib.dontCheck (hself.callHackageDirect {
                pkg = "dyre";
                ver = "0.9.1";
                sha256 = "sha256-3ClPPbNm5wQI+QHaR0Rtiye2taSTF3IlWgfanud6wLg=";
              } { });

            });
        });
      };
      overlays = gtk-strut.overlays ++ gtk-sni-tray.overlays ++ [ overlay ];
    in flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowBroken = true;
        };
      in rec {
        devShell = pkgs.haskellPackages.shellFor {
          packages = p: [ p.taffybar ];
          nativeBuildInputs = with pkgs.haskellPackages; [
            cabal-install
            hlint
            ghcid
            ormolu
            implicit-hie
            haskell-language-server
          ];
        };
        buildInputs = [ pkgs.haskellPackages.cabal-install ];
        defaultPackage = pkgs.haskellPackages.taffybar;
      }) // {
        inherit overlay overlays;
      };
}
