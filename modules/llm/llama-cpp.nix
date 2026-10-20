# llama.cpp from the pinned flake input, nixpkgs is too old for some models
# (embeddinggemma-2 needs 0.7.0+). Every host that imports this gets the same
# source, host overlays (rocm, vulkan, native) stack on top in any order.
{ lib, inputs, ... }:
let
  src = inputs.llama-cpp;
  d = src.lastModifiedDate;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      llama-cpp = prev.llama-cpp.overrideAttrs (old: {
        version = "0.7.0-unstable-${lib.substring 0 4 d}-${lib.substring 4 2 d}-${lib.substring 6 2 d}";
        inherit src;
        patches = [ ];
        # changes with tools/ui/package-lock.json, set lib.fakeHash and copy "got:"
        npmDepsHash = "sha256-hqYzdp1FwPhYkBP278fQXgY9NCKB6Q3P6Gko7BfP0m0=";
        # the recipe hardcodes its own release commit, the later -D wins
        cmakeFlags = old.cmakeFlags ++ [ (lib.cmakeFeature "LLAMA_BUILD_COMMIT" src.shortRev) ];
      });
    })
  ];
}
