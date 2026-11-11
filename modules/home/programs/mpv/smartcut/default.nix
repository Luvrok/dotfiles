{
  lib,
  fetchFromGitHub,
  ffmpeg_7-headless,
  python3Packages,
}:

let
  # smartcut is pinned to PyAV 16, ffmpeg 7 is what that version expects.
  # Keep both here so a nixpkgs update cannot move them under the tool.
  av16 = python3Packages.av.overridePythonAttrs (_: {
    version = "16.0.1";
    src = fetchFromGitHub {
      owner = "PyAV-Org";
      repo = "PyAV";
      tag = "v16.0.1";
      hash = "sha256-iFKDDOJzCynaqwHIjykfh82diGiuOjWytwU3dq1J9PA=";
    };
    buildInputs = [ ffmpeg_7-headless ];
    doCheck = false;
    preCheck = "";
  });
in
python3Packages.buildPythonApplication {
  pname = "smartcut";
  version = "1.7";
  pyproject = true;
  src = fetchFromGitHub {
    owner = "Luvrok";
    repo = "smartcut";
    rev = "04d4a8dc27aa0c38c4f413631b1c190764d49c7c";
    hash = "sha256-wDCtWNCFCC8Ep/5Jwzo/qq87yMAQuOjd1CQXJWTCjk0=";
  };
  build-system = [ python3Packages.setuptools ];
  dependencies = with python3Packages; [ av16 tqdm numpy ];
  doCheck = false;
  meta = {
    description = "Frame-accurate cutting that re-encodes only the cut GOPs";
    homepage = "https://github.com/skeskinen/smartcut";
    license = lib.licenses.mit;
    mainProgram = "smartcut";
  };
}
