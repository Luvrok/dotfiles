{
  lib,
  pkgs,
  config,
}:
let
  remove-binding =
    binding: str:
    let
      bindings = lib.strings.splitString "," str;
      newBindings = lib.lists.remove binding bindings;
    in
    lib.strings.concatStringsSep "," newBindings;
in
with config.programs.rofi.extraConfig;
''
  _rofi () {
    ${config.programs.rofi.package}/bin/rofi \
      -i \
      -kb-accept-custom "" \
      -kb-row-down "${remove-binding "Control+n" kb-row-down}" \
      -kb-row-up "${remove-binding "Control+p" kb-row-up}" \
      -kb-mode-complete "" \
      -kb-remove-char-back "BackSpace,Shift+BackSpace" \
      -kb-move-front "" \
      -kb-remove-to-sol "" \
      -no-auto-select \
      -theme "$HOME"/.config/rofi/rofi-pass.rasi\
      "$@"
  }

  _pwgen () {
    ${pkgs.pwgen}/bin/pwgen -y "$@"
  }

  layout_cmd () {
    :
  }

  _clip_in_primary() { wl-copy --primary; }
  _clip_in_clipboard() { wl-copy; }
  _clip_out_primary() { wl-paste --primary; }
  _clip_out_clipboard() { wl-paste; }

  URL_field='url'
  USERNAME_field='user'
  AUTOTYPE_field='autotype'

  default_autotype="user :tab pass"

  delay=2
  wait=0.2
  type_delay=12

  default_do='copyMenu' # menu, copyPass, typeUser, typePass, copyUser, copyUrl, viewEntry, typeMenu, actionMenu, copyMenu, openUrl
  auto_enter='false'
  notify='true'
  clip=clipboard # primary is middle mouse i guess
  clip_clear=45
  edit_new_pass="true"
  password_length=16
  fix_layout=true

  clipboard_backend=wl-clipboard
  backend=wtype

  # Custom Keybindings
  autotype="Control+a"
  type_pass="Control+p"
  copy_pass="Control+t"
  show="Control+o"
  help="Control+h"
  insert_pass="Alt+n"
''
