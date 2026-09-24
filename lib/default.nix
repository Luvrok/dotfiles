# Helpers shared by the flake and the modules (available as config.galaxy.lib).
{ lib }:

let
  files = import ./files.nix { inherit lib; };

  # Every module under `dir`: plain *.nix files and folders with a default.nix.
  # Folders without a default.nix are searched further.
  listModules =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          if builtins.pathExists (path + "/default.nix") then [ path ] else listModules path
        else if lib.hasSuffix ".nix" name then
          [ path ]
        else
          [ ]
      ) (builtins.readDir dir)
    );
in
{
  inherit (files) linkTree;
  inherit listModules;

  mkHost = import ./mkHost.nix { inherit lib; };
  xray = import ./xray.nix { inherit lib; };

  # Shell script from a file, built with writeShellApplication.
  # bashOptions stay empty: the scripts were written without `set -euo pipefail`.
  mkScript =
    pkgs:
    {
      name,
      src,
      runtimeInputs ? [ ],
      excludeShellChecks ? [ ],
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      bashOptions = [ ];
      text = builtins.readFile src;
    };

  # "#d65d0e" -> "214, 93, 14"
  hexToRgb =
    hex:
    let
      h = lib.removePrefix "#" hex;
      part = i: toString (lib.fromHexString (builtins.substring i 2 h));
    in
    "${part 0}, ${part 2}, ${part 4}";
}
