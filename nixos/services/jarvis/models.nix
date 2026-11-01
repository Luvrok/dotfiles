# every file jarvis downloads, pinned by url and sha256. the sherpa-onnx
# models are github release assets, hashed here. the hugging face ones are
# in models.lock.json: a repo, the commit and a sha256 per file, which
# ./update-models fills in from the hub's api (lfs files carry their
# sha256 there, so nothing big is downloaded for it). no voice files are in
# the dotfiles, only these. huggingface.co answers with a redirect to its
# lfs cdn, and that one is cut off here (tls eof), so the hub's files come
# through proxy (xray's inbound) when there is one: a fixed-output fetch
# shares the host's network, 127.0.0.1 is the host
{
  pkgs,
  lib,
  proxy ? null,
}:

let
  sherpa = "https://github.com/k2-fsa/sherpa-onnx/releases/download";

  # a release tarball, only the files asked for, its top folder dropped
  tarball =
    name: url: hash: files:
    pkgs.runCommandLocal "jarvis-${name}" { src = pkgs.fetchurl { inherit url hash; }; } ''
      mkdir $out
      tar xf $src -C $out --strip-components=1 --wildcards ${lib.escapeShellArgs files}
    '';

  lock = lib.importJSON ./models.lock.json;

  # a hugging face repo at its locked commit, as a folder of links
  hf =
    name:
    let
      e = lock.${name};
    in
    if e.files == { } then
      throw "jarvis: ${e.repo} has no files in models.lock.json yet, run nixos/services/jarvis/update-models"
    else
      pkgs.linkFarm "jarvis-${name}" (
        lib.mapAttrsToList (path: sha256: {
          name = path;
          path = pkgs.fetchurl {
            name = lib.strings.sanitizeDerivationName (baseNameOf path);
            url = "https://huggingface.co/${e.repo}/resolve/${e.rev}/${path}";
            inherit sha256;
            curlOptsList = lib.optionals (proxy != null) [
              "--proxy"
              proxy
            ];
          };
        }) e.files
      );
in
{
  # stt, multilingual whisper small. int8 runs fine on the cpu
  whisper-small =
    tarball "whisper-small" "${sherpa}/asr-models/sherpa-onnx-whisper-small.tar.bz2"
      "sha256-SGpGr7t7p5hQcZD/4C/qLdcmBJryEud0U376xq+yEKY="
      [
        "*/small-encoder.int8.onnx"
        "*/small-decoder.int8.onnx"
        "*/small-tokens.txt"
      ];

  # the wake word, english. bpe.model turns a character's phrase into its
  # tokens at build time
  kws =
    tarball "kws" "${sherpa}/kws-models/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01.tar.bz2"
      "sha256-8XABO0cW5Btiub/YCWh8IHzveY75vGU01SThevm2Vho="
      [
        "*/*.int8.onnx"
        "*/tokens.txt"
        "*/bpe.model"
      ];

  silero-vad = pkgs.fetchurl {
    url = "${sherpa}/asr-models/silero_vad.onnx";
    hash = "sha256-niRJ4Qh0ltjUyrqQfyPgvT942R+lUkebucI6wJy7H9Y=";
  };

  # qwen3-tts: the base model clones a clip, the kurisu finetune has its
  # speakers built in
  tts-base = hf "tts-base";
  tts-kurisu = hf "tts-kurisu";

  # piper voices for the build-time clips (refs.nix), .onnx and .onnx.json
  # only
  piper-jarvis = hf "piper-jarvis";
  piper-glados = hf "piper-glados";
  piper-hal9000 = hf "piper-hal9000";

  # mayuri's clip and its text, from her repo's refs/
  mayuri = hf "mayuri";
}
