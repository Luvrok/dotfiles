{
  dwm,
  src,
  libXcursor,
  libXres,
  yajl,
}:

dwm.overrideAttrs (old: {
  version = "dwm-6.7";
  src = src.outPath;
  buildInputs = (old.buildInputs or [ ]) ++ [
    libXcursor
    libXres
    yajl
  ];
})
