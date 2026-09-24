{
  slock,
  src,
  libX11,
  libxrandr,
  libxcrypt,
  libxext,
  libXinerama,
  imlib2,
  libXft,
}:

slock.overrideAttrs (_: {
  version = "slock-1.6";
  src = src.outPath;
  buildInputs = [
    libX11
    libxrandr
    libxcrypt
    libxext
    libXinerama
    imlib2
    libXft
  ];
})
