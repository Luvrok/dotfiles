{
  st,
  src,
  libX11,
  libXft,
  imlib2,
}:

st.overrideAttrs (_: {
  version = "st-0.9.3";
  src = src.outPath;
  buildInputs = [
    libX11
    libXft
    imlib2
  ];
})
