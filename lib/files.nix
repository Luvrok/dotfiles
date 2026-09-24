{ lib }:

{
  # Flatten a directory into { "<target>/<relative path>" = <file>; },
  # so every file gets its own link and generated files can sit next to them.
  linkTree =
    target: src:
    let
      walk =
        rel: dir:
        lib.concatMapAttrs (
          name: type:
          let
            path = dir + "/${name}";
            relName = if rel == "" then name else "${rel}/${name}";
          in
          if type == "directory" then walk relName path else { "${target}/${relName}" = path; }
        ) (builtins.readDir dir);
    in
    walk "" src;
}
