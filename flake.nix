
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.mixtonix.url = "git+https://github.com/serokell/mix-to-nix?ref=fix-on-20.03";

  outputs = { self, nixpkgs, mixtonix }: {

    overlay = self: super: {
      foo = with super;
      let
         elixir = (beam.packagesWith erlangR23).elixir_1_11;

      in stdenv.mkDerivation {
        name    = "foo";

        hardeningDisable  = [ "all" ];
        buildInputs       = [ elixir gdb libpcap pv ];
        nativeBuildInputs = [ elixir gcc10 ];
      };
    };

    defaultPackage.x86_64-linux = (import nixpkgs { system = "x86_64-linux"; overlays = [ self.overlay ]; }).foo;
  };
}

