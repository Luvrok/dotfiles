{ lib, ... }:

{
  options.videoDrivers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
  };
  options.dpi = lib.mkOption {
    type = lib.types.int;
  };
  options.fontSize = lib.mkOption {
    type = lib.types.int;
  };
}
