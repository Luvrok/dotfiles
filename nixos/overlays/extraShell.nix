{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ssh" ''
      TERM=xterm ${pkgs.openssh}/bin/ssh "$@"
    '')
    (pkgs.writeShellScriptBin "ocr" ''
      flameshot gui --raw --accept-on-select \
        | tesseract -l eng+rus stdin stdout 2>/dev/null \
        | xclip -selection clipboard
      notify-send "OCR" "Text copied"
    '')
  ];
}
