{
  description = "rogryza.me blog";

  inputs.nixpkgs.url = github:NixOs/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in {
    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = with pkgs; [ nodejs wrangler zola ];
    };
  };
}
