# nix-meta

**Metadata for Nix: embed, query, and strip it on any expression.**

`nix-meta` embeds metadata as an attribute set under a `_meta` marker in a Nix expression, then traverses the expression to find, update, or remove it.

Built on [nix-ast](https://github.com/z1-0/nix-ast).

## Usage

**Flake input:**

```nix
{
  inputs.nix-meta.url = "github:z1-0/nix-meta";

  outputs = { nix-meta, ... }: {
    lib = nix-meta.lib;
  };
}
```

## API

### get

```
get :: pkgs -> [AST] -> [a | null]
```

For each AST, find and evaluate the first `_meta` binding.

Returns one element per input AST, in the same order. `null` where an AST has no `_meta`.

```nix
meta.lib.get pkgs [ ast1 ast2 ]
# -> [ metadata-or-null, metadata-or-null ]
```

### set

```
set :: a -> AST -> AST
```

Attach metadata to an AST. If metadata already exists, it is replaced.

Returns the AST with metadata embedded.

```nix
meta.lib.set { version = "1.0"; author = "me"; } ast
# -> ast with metadata attached
```

### remove

```
remove :: AST -> AST
```

Remove the first `_meta` binding from an AST.

```nix
meta.lib.remove ast
# -> ast with first _meta removed
```

### Re-exports

`nix-meta` re-exports the full [`nix-ast`](https://github.com/z1-0/nix-ast) API. See [its documentation](https://github.com/z1-0/nix-ast#api).

## Example

**Inspect metadata across multiple files:**

```nix
let
  inherit (nix-meta) parse get;

  asts = parse pkgs [
    ./maintainers/alice.nix   # { _meta = { email = "alice@email.com"; }; outputs = { ... }; }
    ./maintainers/bob.nix     # { outputs = { ... }; }
    ./maintainers/charlie.nix # { _meta = { email = "charlie@email.com"; }; outputs = { ... }; }
  ];

  metas = get pkgs asts; # [ { email = "alice@example.com"; } null { email = "charlie@example.com"; } ]
in
```
