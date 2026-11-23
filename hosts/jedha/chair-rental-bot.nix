# CUTLAB chair rental bot on jedha.
#
# it runs here, not on the ru vps: jedha reaches api.telegram.org through the
# local xray mixed inbound, and the token, the database and the client names
# stay on the home server. mos-eisley only serves the cutlab landing page.
{ config, ... }:

{
  sops.secrets.telegram_bot_token = { };
  sops.secrets.telegram_admin_id = { };

  systemd.tmpfiles.rules = [ "d /run/chair-bot 0750 root root -" ];

  # systemd reads the EnvironmentFile as root, the bot user never sees it
  sops.templates."chair-bot.env" = {
    path = "/run/chair-bot/bot.env";
    owner = "chairbot";
    group = "chairbot";
    mode = "0400";
    content = ''
      BOT_TOKEN=${config.sops.placeholder.telegram_bot_token}
      ADMIN_TELEGRAM_ID=${config.sops.placeholder.telegram_admin_id}
    '';
    restartUnits = [ "chair-rental-bot.service" ];
  };

  services.chair-rental-bot = {
    enable = true;
    environmentFile = "/run/chair-bot/bot.env";
    proxy = "http://127.0.0.1:10808";
  };
}
