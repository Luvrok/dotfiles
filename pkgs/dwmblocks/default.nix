{
  dwmblocks,
  src,
  libX11,
  libxcb,
  xcbutil,
  pkg-config,
}:

dwmblocks.overrideAttrs (_: {
  src = src.outPath;
  buildInputs = [
    libX11
    libxcb
    xcbutil
    pkg-config
  ];
  makeFlags = [ "PREFIX=$(out)" ];
  postPatch = ''
    if grep -q 'void termhandler()' src/main.c; then
      substituteInPlace src/main.c \
        --replace-fail 'void termhandler()' 'void termhandler(int signum)'
    fi
  '';
})
