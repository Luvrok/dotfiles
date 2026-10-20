# docs that nix keeps in the docs-mcp index, by where they come from. no
# crawl patterns: each kind is a page list someone already made. a changed
# entry is scraped again from scratch, a removed one leaves the index,
# libraries added by hand stay
{ pkgs, config }:
{
  # curated pages from devdocs.io, slug as in https://devdocs.io/docs.json
  devdocs = {
    go-std = "go";
  };

  # markdown straight from the repo
  github = {
    nix-dev = "https://github.com/NixOS/nix.dev/tree/master/source";
    llama-cpp = "https://github.com/ggml-org/llama.cpp/tree/master/docs";
    xray = "https://github.com/XTLS/Xray-docs-next/tree/main/docs/en";
  };

  # built from the locked nixpkgs, same versions as the system. a folder
  # keeps only its html pages
  local = {
    nix-manual = "${pkgs.nix.doc}/share/doc/nix/manual";
    # one page, the folder has it again as manual.html
    nixpkgs-manual = "${pkgs.nixpkgs-manual}/share/doc/nixpkgs/index.html";
    # only the manual itself, without options.html and the release notes
    nixos-manual = "${config.system.build.manual.manualHTML}/share/doc/nixos/index.html";
  };

  # one plain page, only when nothing above has it
  web = {
    i3 = "https://i3wm.org/docs/userguide.html";
  };
}
