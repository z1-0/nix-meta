{
  inputs.nix-ast.url = "github:z1-0/nix-ast";

  outputs = inputs: { lib = import ./default.nix { inherit (inputs) nix-ast; }; };
}
