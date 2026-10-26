# kodi's estuary in the quickshell look: ./colors.xml and its font, a home
# menu with only what /media/outer-1 has (./home-menu.xml). the id stays
# skin.estuary, so kodi keeps it a system add-on (enabled, the default skin,
# nothing to pick in the settings). kodi takes ~/.kodi/addons over its own
# copy when the version isn't lower. built from the estuary of the kodi it
# runs on, and only changed where it's named: when a kodi update moves
# something, nixos-rebuild fails here, kodi keeps working
{
  runCommand,
  kodi,
  nerd-fonts,
  imagemagick,
  python3,
}:

let
  fonts = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
in
runCommand "kodi-skin-estuary-barnard"
  {
    nativeBuildInputs = [
      imagemagick
      python3
    ];
  }
  ''
    cp -r --no-preserve=mode ${kodi}/share/kodi/addons/skin.estuary $out
    cd $out

    # ./colors.xml over estuary's own, the colors it doesn't name stay
    python3 - ${./colors.xml} colors/defaults.xml <<'EOF'
    import sys
    import xml.etree.ElementTree as ET

    ours = {c.get("name"): c.text for c in ET.parse(sys.argv[1]).iter("color")}
    tree = ET.parse(sys.argv[2])
    for color in tree.iter("color"):
        color.text = ours.pop(color.get("name"), color.text)
    if ours:
        sys.exit(f"estuary has no colors {sorted(ours)}")
    tree.write(sys.argv[2], encoding="utf-8", xml_declaration=True)
    EOF

    grep -q '<onload>ReplaceWindow' xml/Startup.xml
    sed -i '/<window>/r ${./home-menu.xml}' xml/Startup.xml

    # a short scroll and no focus animation. a list scrolled 200-500 ms on
    # every wheel step, the item under the mouse zoomed and faded in, so the
    # focus jumped around under the cursor while the list moved. with no
    # scroll at all fast wheeling jumped instead. an animation that hides
    # something on focus still does, at once
    sed -i -E \
      -e 's#(<scrolltime[^>]*>)[0-9]+#\1150#' \
      -e '/>(Focus|Unfocus)<\/animation>/s#time="[0-9]+"#time="0"#' \
      xml/*.xml

    # the logo over the home menu was the only blue left, grey now
    magick ${kodi}/share/kodi/media/vendor_logo.png -colorspace gray extras/logo.png
    substituteInPlace xml/Home.xml \
      --replace-fail special://xbmc/media/vendor_logo.png special://skin/extras/logo.png

    # Theme.font. the thin one is the clock on the home screen. the arial
    # fontset (languages noto has no letters for) stays
    cp ${fonts}/JetBrainsMonoNLNerdFont-{Regular,Thin}.ttf fonts/
    substituteInPlace xml/Font.xml \
      --replace-fail NotoSans-Regular.ttf JetBrainsMonoNLNerdFont-Regular.ttf \
      --replace-fail NotoMono-Regular.ttf JetBrainsMonoNLNerdFont-Regular.ttf \
      --replace-fail Roboto-Thin.ttf JetBrainsMonoNLNerdFont-Thin.ttf
  ''
