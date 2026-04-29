{ ... }:

{
  programs.element-desktop = {
    enable = true;
    settings = {
      "default_server_name" = "4d2.org";
      show_labs_settings = true;
      element_call = {
        use_exclusively = true;
        brand = "Element Call";
        guest_spa_url = "https://call.element.io";
      };
      features = {
        feature_element_call_video_rooms = true;
        feature_group_calls = true;
        feature_video_rooms = true;
      };
      setting_defaults = {
        "UIFeature.voip" = true;
        "UIFeature.advancedSettings" = true;
        "UIFeature.advancedEncryption" = true;
        "UIFeature.widgets" = true;
        "UIFeature.feedback" = false;
      };
    };
  };
}
