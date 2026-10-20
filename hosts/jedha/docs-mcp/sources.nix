# docs that nix keeps in the docs-mcp index. name and url go to
# `scrape <name> <url>`, any other attr becomes a flag of it
# (max-pages = 3000 -> --max-pages=3000, a list repeats the flag), see
# `docs-mcp scrape --help`. a changed entry is scraped again from scratch, a
# removed one is removed from the index. libraries added by hand stay.
# scrape-mode is fetch unless set here: auto and playwright start chromium
[
  {
    name = "nix-dev";
    url = "https://nix.dev/";
  }
  {
    name = "nixpkgs-manual";
    url = "https://nixos.org/manual/nixpkgs/unstable/";
  }
  {
    name = "nixos-manual";
    url = "https://nixos.org/manual/nixos/unstable/";
    # every nixos option on one page, tens of thousands of chunks
    exclude-pattern = [ ''/\/options(\.html)?$/'' ];
  }
  {
    name = "go-std";
    url = "https://pkg.go.dev/std";
    # packages sit next to /std, not under it, and the links carry @goX.Y.Z.
    # a dot in the first segment is a module (github.com/...), not std
    scope = "hostname";
    include-pattern = [ ''/^\/[a-z0-9_]+(\/[a-z0-9_]+)*(@go[0-9.]+)?$/'' ];
    exclude-pattern = [
      ''/^\/(about|api|license-policy|badge|search|static)(\/|@|$)|\/internal(\/|@|$)/''
    ];
  }
  {
    name = "llama-cpp";
    url = "https://github.com/ggml-org/llama.cpp/tree/master/docs";
  }
  {
    name = "xray";
    url = "https://xtls.github.io/en/";
  }
  {
    name = "i3";
    url = "https://i3wm.org/docs/userguide.html";
  }
]
