# the reference clips the base model clones: ref.wav and ref.txt per
# character. piper reads the character's ref.txt once at build time, about
# 15 s of plain speech, and is never used after. mayuri's comes from her
# repo as is
{
  pkgs,
  lib,
  models,
}:

let
  piper =
    id: voice:
    pkgs.runCommandLocal "jarvis-ref-${id}" { nativeBuildInputs = [ pkgs.piper-tts ]; } ''
      mapfile -t onnx < <(find -L ${voice} -name '*.onnx')
      if [ ''${#onnx[@]} -ne 1 ]; then
        echo "jarvis: ${id} needs exactly one .onnx voice, ${voice} has: ''${onnx[*]}" >&2
        exit 1
      fi
      mkdir $out
      # one line, piper reads a line as a sentence group
      tr '\n' ' ' < ${./characters + "/${id}/ref.txt"} | sed 's/ *$//' > $out/ref.txt
      piper -m "''${onnx[0]}" -c "''${onnx[0]}.json" -i $out/ref.txt -f $out/ref.wav
    '';

  # a clip and its transcript from a repo: the neutral one, else happy,
  # else the first. the text is the .txt (or .lab) of the same name
  clip =
    id: src:
    pkgs.runCommandLocal "jarvis-ref-${id}" { } ''
      pick() { find -L ${src} -iname '*.wav' | sort | grep -i "$1" | head -n1; }
      wav=$(pick neutral); [ -n "$wav" ] || wav=$(pick happy); [ -n "$wav" ] || wav=$(pick .)
      if [ -z "$wav" ]; then
        echo "jarvis: no wav for ${id} in ${src}" >&2
        exit 1
      fi
      txt=""
      for ext in txt lab; do
        [ -e "''${wav%.*}.$ext" ] && txt="''${wav%.*}.$ext" && break
      done
      if [ -z "$txt" ]; then
        echo "jarvis: no transcript next to $wav" >&2
        exit 1
      fi
      mkdir $out
      cp "$wav" $out/ref.wav
      tr '\n' ' ' < "$txt" | sed 's/ *$//' > $out/ref.txt
    '';
in
{
  jarvis = piper "jarvis" models.piper-jarvis;
  glados = piper "glados" models.piper-glados;
  hal9000 = piper "hal9000" models.piper-hal9000;
  mayuri = clip "mayuri" models.mayuri;
}
