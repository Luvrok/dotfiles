# kodi with the add-ons of ./addons.nix, and what kodi has to turn on by
# hand afterwards (./userdata.nix). ./default.nix is the module, this is
# just the package
{ pkgs, inputs }:

let
  # ./kodi-keys.patch: a ru layout's keys are the us ones in the keymaps
  # (./keyboard.xml; kodi gave every cyrillic letter one code), and
  # shift+letter goes through them too (G, the last item; it jumped to the
  # first item with that letter). kodi builds from source then, not from
  # the cache. a kodi it doesn't apply to fails the build: the patch is
  # three small hunks, redo them or drop the line (keys on ru stop working)
  kodi = pkgs.kodi-wayland.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./kodi-keys.patch ];
  });
  kodiPackages = kodi.packages;
  addons = kodiPackages.callPackage ./addons.nix { inherit inputs; };
  kodiWithAddons = kodi.withPackages (_: addons);

  # tmdb through xray's mixed inbound (hosts/barnard/xray.nix) when the
  # provider breaks it: kodi's curl (posters) and the scrapers' urllib
  # take the proxy from the environment. no internet in kodi while xray
  # is off
  useProxy = false;
  proxy = "http://127.0.0.1:10808";
in
{
  package =
    if useProxy then
      pkgs.symlinkJoin {
        name = "kodi-xray";
        paths = [ kodiWithAddons ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/kodi \
            --set http_proxy ${proxy} \
            --set https_proxy ${proxy} \
            --set no_proxy localhost,127.0.0.1,::1
        '';
      }
    else
      kodiWithAddons;

  # the add-ons and what they need: kodi installs them switched off
  addonIds = map (a: a.namespace) (kodiPackages.requiredKodiAddons addons);
}
