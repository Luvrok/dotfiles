{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ssh" ''
      TERM=xterm ${pkgs.openssh}/bin/ssh "$@"
    '')
    (pkgs.writeShellScriptBin "ocr" ''
      g=$(${pkgs.slurp}/bin/slurp) || exit 0
      ${pkgs.grim}/bin/grim -g "$g" - \
        | tesseract -l eng+rus stdin stdout 2>/dev/null \
        | ${pkgs.wl-clipboard}/bin/wl-copy
      notify-send "OCR" "Text copied"
    '')
  ];
}
