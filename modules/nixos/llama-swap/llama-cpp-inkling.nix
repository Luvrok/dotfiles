{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  shaderc,
  openssl,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
}:

# nixpkgs' llama.cpp is too old for Inkling 2 Mini: the looped arch landed in
# #32694/#32695 and the quant scales fix (#32704) was merged after the 0.7.0
# tag. both GGUFs we use are inkling2/inkling2_loop, so one build reads them.
# only llama-server, no UI, no tests: the UI is fetched from HF and would need
# its own npm hash at every pin.
stdenv.mkDerivation {
  pname = "llama-cpp-inkling";
  version = "0.7.0-unstable-2026-11-21";

  src = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    # merge of #32704, on top of #32694: without it NVFP4 loop slots lose
    # their per-expert scales and the second and third passes give gibberish
    rev = "690b87d88151dbd775bb6eff5581663688785928";
    hash = "sha256-5uAFmAICM75/TncEPw8NMjH9xguhzYYAVjGix7t8nBk=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    shaderc
  ];

  buildInputs = [
    openssl
    spirv-headers
    vulkan-headers
    vulkan-loader
  ];

  cmakeFlags = [
    (lib.cmakeBool "GGML_NATIVE" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" false)
    (lib.cmakeBool "LLAMA_BUILD_IS_DEV" false)
    (lib.cmakeBool "LLAMA_BUILD_APP" false)
    (lib.cmakeBool "LLAMA_BUILD_HTML" false)
    (lib.cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (lib.cmakeBool "LLAMA_BUILD_SERVER" true)
    (lib.cmakeBool "LLAMA_BUILD_TESTS" false)
    (lib.cmakeBool "LLAMA_BUILD_UI" false)
    (lib.cmakeBool "LLAMA_USE_PREBUILT_UI" false)
    (lib.cmakeBool "LLAMA_OPENSSL" true)
    (lib.cmakeBool "GGML_VULKAN" true)
  ];

  doCheck = false;
  enableParallelBuilding = true;

  meta = {
    description = "llama.cpp with Inkling 2 Mini (looped MoE) support, Vulkan";
    homepage = "https://github.com/ggml-org/llama.cpp";
    license = lib.licenses.mit;
    mainProgram = "llama-server";
    platforms = lib.platforms.unix;
  };
}
