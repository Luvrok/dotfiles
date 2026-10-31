# a kodi to try ../ in without a switch (./run.sh): barnard's add-ons, skin
# and its patches from this working tree, in a home of its own.
#   mock (default): x11 kodi for a screen of xvfb, tmdb helper asking
#     ./mock.py instead of tmdb, movie pipe radarr's and sonarr's (a
#     container with no internet, no arr)
#   mock = false: wayland kodi, a window on this screen, the real tmdb and
#     arr (barnard)
# --impure: the flake's inputs, read from ../../../..
{
  mock ? true,
  keys ? "/tmp/kodi-test/keys",
}:

let
  flake = builtins.getFlake (toString ../../../..);
  inputs = flake.inputs;
  pkgs = import inputs.nixpkgs-kodi { system = builtins.currentSystem; };
  kodi = if mock then pkgs.kodi else pkgs.kodi-wayland;

  # tmdb helper's api and images at the mock's port
  tmdbhelper = pkgs.runCommand "tmdbhelper-mock" { } ''
    cp -r ${inputs.kodi-tmdbhelper} $out
    chmod -R u+w $out
    grep -rlZ 'themoviedb.org/3\|api.tmdb.org/3\|image.tmdb.org/t/p' $out/resources | xargs -0 sed -i \
      -e 's#https://api.themoviedb.org/3#http://127.0.0.1:8765/3#g' \
      -e 's#https://api.tmdb.org/3#http://127.0.0.1:8765/3#g' \
      -e 's#https://image.tmdb.org/t/p#http://127.0.0.1:8765/img#g'
  '';
  addons = kodi.packages.callPackage ../addons.nix (
    if mock then
      {
        inputs = inputs // {
          kodi-tmdbhelper = {
            outPath = tmdbhelper;
            shortRev = "mock";
          };
        };
        arr = import ../../arr/shared.nix // {
          inherit keys;
        };
      }
    else
      { inherit inputs; }
  );
in
{
  kodi = kodi.withPackages (_: addons);
  # what userdata.py turns on
  ids = builtins.concatStringsSep " " (
    map (a: a.namespace) (kodi.packages.requiredKodiAddons addons)
  );
  # the screen with no screen and its gl, keys pressed from outside, the
  # certificate of ./xray.py's image.tmdb.org
  tools = {
    inherit (pkgs) mesa xdotool imagemagick;
    xvfb = pkgs.xorg.xvfb;
    openssl = pkgs.openssl.bin;
  };
}
