{
  description = "My personal blog.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # use `nix flake lock --update-input pypi-deps-db` to update the pypi database
    # or `nix flake update` to update all
    pypi-deps-db = {
      url = "github:DavHau/pypi-deps-db";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.mach-nix.follows = "mach-nix";
    };

    mach-nix = {
      url = "github:DavHau/mach-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.pypi-deps-db.follows = "pypi-deps-db";
    };

    dart-sass = {
      # TODO Can I make version a variable?
      url =
        "https://github.com/sass/dart-sass/releases/download/1.49.11/dart-sass-1.49.11-linux-x64.tar.gz";
      type = "tarball";
      flake = false;
    };

  };
  outputs = { nixpkgs, flake-utils, mach-nix, dart-sass, ...}:

  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Do NOT use import mach-nix {inherit system;};
    #
    # otherwise mach-nix will not use flakes and pypi-deps-db
    # input will not be used:
    # https://github.com/DavHau/mach-nix/issues/269#issuecomment-841824763
    mach = mach-nix.lib.${system};

    python-env = mach.mkPython {
      python = "python37";
      requirements = "statik";
    };

    pkg-dart-sass = pkgs.stdenv.mkDerivation rec {
      inherit system;

      name = "dart-sass-${version}";
      # TODO how do I make version into a variable?
      version = "1.49.11";

      isExecutable = true;

      src = dart-sass;

      phases = "unpackPhase installPhase";

      installPhase = ''
        mkdir -p $out/bin
        cp -r . $out
        ln -s $out/sass $out/bin/sass
        '';
    };

  in
  {
    devShells.${system}.default = pkgs.mkShellNoCC {
      buildInputs = [ python-env pkg-dart-sass ];
    };
  };
}
