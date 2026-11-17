{ ... }:

let
  # The same face and size as librewolf (settings.nix) and the gtk
  # settings. These only cover message bodies: the window chrome takes its
  # font from gtk through the desktop portal.
  fonts = {
    "font.default.x-western" = "sans-serif";
    "font.name.sans-serif.x-western" = "JetBrainsMonoNL Nerd Font Propo";
    "font.name.monospace.x-western" = "JetBrainsMonoNL Nerd Font Propo";
    "font.size.variable.x-western" = 14;
    "font.size.monospace.x-western" = 14;
  };

  display = {
    # dark rendering inside messages, the same value librewolf uses for sites
    "layout.css.prefers-color-scheme.content-override" = 0;

    "mailnews.start_page.enabled" = false;
    "mail.biff.play_sound" = false;
    "mail.chat.enabled" = false;

    # Sender css is dropped, multipart/alternative prefers the text part and
    # nothing loads from the network until asked: no tracking pixels
    "mailnews.display.html_as" = 1; # simple html, not original html
    "mailnews.display.prefer_plaintext" = true;
    "mailnews.message_display.disable_remote_image" = true;

    "mail.wrap_long_lines" = true;
    "mailnews.wraplength" = 72;
    "mail.spellcheck.inline" = true;
  };

  privacy = {
    "privacy.donottrackheader.enabled" = true;
    "toolkit.telemetry.enabled" = false;
    "datareporting.policy.dataSubmissionEnabled" = false;
    "app.normandy.enabled" = false;
    "app.shield.optoutstudies.enabled" = false;
  };

  ui = {
    # declarative add-ons start enabled instead of waiting for a click
    "extensions.autoDisableScopes" = 0;
    # the hyprland file chooser portal instead of gtk's own dialog
    "widget.use-xdg-desktop-portal.file-picker" = 1;
    # no "is thunderbird your default mail app" prompt on every start, the
    # mailto handler is declared in modules/nixos/xdg
    "mail.shell.checkDefaultClient" = false;
  };

  # Everything goes through xray's mixed inbound (hosts/barnard/xray.json):
  # it sends geoip:ru direct and the rest out through the vps. socks rather
  # than http because imap and smtp are not http, and remote dns so yahoo
  # resolves at the exit. with xray down there is no mail at all
  proxy = {
    "network.proxy.type" = 1;
    "network.proxy.socks" = "127.0.0.1";
    "network.proxy.socks_port" = 10808;
    "network.proxy.socks_version" = 5;
    "network.proxy.socks_remote_dns" = true;
  };
in
{
  settings = fonts // display // privacy // ui // proxy;
}
