# kodi's estuary in the quickshell look: ./colors.xml and its font, a home
# menu with only what /media/outer-1 has (./Startup.xml). the id stays
# skin.estuary, so kodi keeps it a system add-on (enabled, the default skin,
# nothing to pick in the settings). kodi takes ~/.kodi/addons over its own
# copy when the version isn't lower
{
  runCommand,
  kodi,
  nerd-fonts,
  imagemagick,
}:

let
  fonts = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
in
runCommand "kodi-skin-estuary-barnard" { nativeBuildInputs = [ imagemagick ]; } ''
  cp -r --no-preserve=mode ${kodi}/share/kodi/addons/skin.estuary $out
  cd $out

  cp ${./colors.xml} colors/defaults.xml
  cp ${./Startup.xml} xml/Startup.xml

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
