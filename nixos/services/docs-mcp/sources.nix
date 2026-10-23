# docs that nix keeps in the docs-mcp index, by where they come from. no
# crawl patterns: each kind is a page list someone already made. a changed
# entry is scraped again from scratch, a removed one leaves the index,
# libraries added by hand stay. the pi skill (home/programs/pi) lists these
# names, so a model knows what's there
{ pkgs, config }:
{
  # curated pages from devdocs.io, slug as in https://devdocs.io/docs.json
  devdocs = {
    go-std = "go";
  };

  # docs straight from a repo dir. only markdown by default: docs-mcp takes
  # every text file it knows there (conf.py, css, html templates, csv,
  # yaml), that was most of the junk. `include` widens it
  github = {
    nix-dev = "https://github.com/NixOS/nix.dev/tree/master/source";
    llama-cpp = "https://github.com/ggml-org/llama.cpp/tree/master/docs";
    xray = "https://github.com/XTLS/Xray-docs-next/tree/main/docs/en";
    pi = "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/docs";
    llama-swap = {
      url = "https://github.com/mostlygeek/llama-swap/tree/main/docs";
      # the whole config reference is this one file
      include = [ "**/config.example.yaml" ];
    };
  };

  # built from the locked nixpkgs, same versions as the system. a folder
  # keeps only its html pages. `drop` takes dirs or files out first,
  # `dedupe` keeps a repeated h2 section (by id) in the first page only
  local = {
    nix-manual = {
      path = "${pkgs.nix.doc}/share/doc/nix/manual";
      # 68 changelog pages that crowd out the real ones in search
      drop = [ "release-notes" ];
      # every one of the 97 nix3-* pages repeats these
      dedupe = [
        "common-evaluation-options"
        "common-flake-related-options"
        "logging-related-options"
        "miscellaneous-global-options"
        "options-that-change-the-interpretation-of-installables"
      ];
    };
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
