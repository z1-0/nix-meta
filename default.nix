{ nix-ast }:

let
  inherit (nix-ast.lib)
    match
    toAST
    syntax
    traversal
    ;
  inherit (syntax)
    mkNamedVar
    mkStaticKey
    isStaticKey
    isSet
    ;
  inherit (traversal) universe rewrite;

  KEY = "_meta";

  isMetaBinding =
    binding:
    match binding {
      NamedVar =
        { attrPath, ... }:
        let
          h = builtins.head attrPath;
        in
        isStaticKey h && h.contents == KEY;
      _ = _: false;
    };

  cleanBindings = builtins.filter (b: !isMetaBinding b);

  mapSetBindings =
    f: ast:
    rewrite (
      node:
      match node {
        Set = set: set // { bindings = f set.bindings; };
        _ = _: null;
      }
    ) ast;
in
{
  get =
    ast:
    let
      found = builtins.concatMap (set: map (b: b.value) (builtins.filter isMetaBinding set.bindings)) (
        builtins.filter isSet (universe ast)
      );
    in
    if found == [ ] then null else builtins.head found;

  remove = mapSetBindings cleanBindings;

  set =
    meta: ast:
    mapSetBindings (b: cleanBindings b ++ [ (mkNamedVar [ (mkStaticKey KEY) ] (toAST meta)) ]) ast;
}
