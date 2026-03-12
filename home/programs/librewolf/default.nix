{ pkgs, ... }:

let
  extension = shortId: extension_id: {
    name = extension_id;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
      allowed_in_private_browsing = true;
    };
  };
in
{
  programs.librewolf = {
    enable = true;

    policies = {
      DNSOverHTTPS = {
        ProviderUrl = "dns.quad9.net";
      };

      ExtensionSettings = {

      } //
      builtins.listToAttrs [
        (extension "sidebery" "{3c078156-979c-498b-8990-85f7987dd929}")
        (extension "sponsorblock" "sponsorBlocker@ajay.app")
        (extension "ublock-origin" "uBlock0@raymondhill.net")
        (extension "remove-youtube-shorts" "{2766e9f7-7bf2-4c72-81b9-d119eb54c753}")
        (extension "gruvboxtheme" "{fd4fdeb0-5a65-4978-81c5-3488d4d56426}")
        (extension "styl-us" "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}")
        (extension "foxyproxy-standard" "foxyproxy@eric.h.jung")
        (extension "video-downloadhelper" "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}")
        (extension "immersive-translate" "{5efceaa7-f3a2-4e59-a54b-85319448e305}")
      ];
    };

    profiles = {
      "life" = {
        id = 0;
        isDefault = true;
      };
      "work" = {
        id = 1;
      };
    };
  };
}
