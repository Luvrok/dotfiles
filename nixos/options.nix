{ lib, ... }:

{
  options.videoDrivers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
  };
  options.fontSize = lib.mkOption {
    type = lib.types.int;
  };
}
