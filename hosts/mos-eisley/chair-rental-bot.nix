# CUTLAB chair rental bot on mos-eisley.
#
# the bot repository is the flake input chair-rental-bot: it carries the
# package and the services.chair-rental-bot module (postgres, systemd unit,
# nightly dump). this file only feeds the two secrets and turns it on.
{ config, ... }:

{
  sops.secrets.telegram_bot_token = { };
  sops.secrets.telegram_admin_id = { };

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
  };
}
