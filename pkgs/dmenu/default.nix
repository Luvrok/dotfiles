{
  dmenu,
  src,
  libX11,
  libXinerama,
  libXft,
  pkg-config,
}:

dmenu.overrideAttrs {
  src = src.outPath;
  buildInputs = [
    libX11
    libXinerama
    libXft
    pkg-config
  ];
  makeFlags = [ "PREFIX=$(out)" ];
}
