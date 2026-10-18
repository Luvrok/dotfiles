{ ... }:

{
  environment.variables = {
    TERMINAL = "kitty";
    BROWSER = "librewolf";
    UDEVIL_CONF_PATH = "/etc/udevil/udevil.conf";
    PASSWORD_STORE_DIR = "$HOME/.password-store";
    TERM = "xterm-256color";
    TOR_SOCKS_PORT = "9050";
    MOZ_X11_EGL = "1";
    ROFI_PASS_CLIPBOARD_BACKEND = "xclip";
    ROFI_PASS_BACKEND = "xdotool";
  };

  environment.localBinInPath = true;
}
