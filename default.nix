{ nix-ast }:

let
  inherit (nix-ast.lib) eval match syntax toAST;
  inherit (syntax) mkNamedVar mkStaticKey isStaticKey;

  KEY = "_meta";

  isMetaBinding =
    binding:
    match binding {
      NamedVar =
        { attrPath, ... }:
        if attrPath == [] then false else
        let
          h = builtins.head attrPath;
        in
        isStaticKey h && h.contents == KEY;
      _ = _: false;
    };

  hasMeta = node: builtins.any isMetaBinding node.bindings;

  updateMeta =
    metaAST: node:
    node
    // {
      bindings = map (b: if isMetaBinding b then b // { value = metaAST; } else b) node.bindings;
    };

  insertMeta =
    metaAST: node:
    node // { bindings = node.bindings ++ [ (mkNamedVar [ (mkStaticKey KEY) ] metaAST) ]; };

  # Passthrough and restructuring helper for wrappers
  processWrapper =
    ast: body:
    let
      res = findTopContainerCtx body;
    in
    if res == null then null else [ (builtins.elemAt res 0) (x: ast // { body = (builtins.elemAt res 1) x; }) ];

  # Peels one wrapper layer to find the top-level metadata container
  findTopContainerCtx =
    ast:
    match ast {
      Set = _: [ ast (x: x) ];

      Let = { body, ... }:
        if hasMeta ast then
          [ ast (x: x) ]
        else
          let res = processWrapper ast body; in
          if res == null then [ ast (x: x) ] else res;

      With = { body, ... }: processWrapper ast body;
      Assert = { body, ... }: processWrapper ast body;
      Abs = { body, ... }: processWrapper ast body;

      _ = _: null;
    };
in

nix-ast.lib // {
  /**
    Extract the first `_meta` from each AST and evaluate it.

    Results keep input order. Returns null for ASTs without `_meta`.

    # Type
    get :: pkgs -> [AST] -> [a | null]
  */
  get =
    pkgs: asts:
    let
      # Extract _meta nodes from all ASTs (null if absent)
      metas = map (ast:
        let
          found = findTopContainerCtx ast;
        in
        if found == null then null else
        let
          metaBindings = builtins.filter isMetaBinding (builtins.elemAt found 0).bindings;
        in
        if metaBindings == [] then null else (builtins.head metaBindings).value
      ) asts;

      # Filter out non-null nodes for batch eval
      nonNullASTs = builtins.filter (m: m != null) metas;
      evaluated = if nonNullASTs == [] then [] else eval pkgs nonNullASTs;

      # Rebuild original order by slotting eval results into non-null positions
      zipMetas = ms: evs:
        if ms == [] then [] else
        let
          m = builtins.head ms;
          tailMs = builtins.tail ms;
        in
        if m == null then
          [ null ] ++ zipMetas tailMs evs
        else
          [ (builtins.head evs) ] ++ zipMetas tailMs (builtins.tail evs);
    in
    zipMetas metas evaluated;

  /**
    Update the first `_meta` binding in the AST.

    When there is none, add `_meta` to the first binding container.

    # Type
    set :: a -> AST -> AST
  */
  set =
    meta: ast:
    let
      found = findTopContainerCtx ast;
    in
    if found != null then
      let
        node = builtins.elemAt found 0;
        replace = builtins.elemAt found 1;
        metaAST = toAST meta;
      in
      if hasMeta node then
        replace (updateMeta metaAST node)
      else
        replace (insertMeta metaAST node)
    else
      ast;

  /**
    Remove the first `_meta` binding in the AST.

    # Type
    remove :: AST -> AST
  */
  remove =
    ast:
    let
      found = findTopContainerCtx ast;
    in
    if found != null then
      let
        node = builtins.elemAt found 0;
        replace = builtins.elemAt found 1;
        newBindings = builtins.filter (b: !isMetaBinding b) node.bindings;
      in
      # Safety: if a Let expression loses all bindings, return its body directly to avoid an empty "let in"
      if node.tag == "Let" && newBindings == [] then
        replace node.body
      else
        replace (node // { bindings = newBindings; })
    else
      ast;
}
