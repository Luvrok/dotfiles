{ ... }:

{
  networking.wireless.iwd = {
    enable = true;
    settings = {
      Settings.AutoConnect = true;
      General = {
        AddressRandomization = "network";
        AddressRandomizationRange = "full";
        EnableNetworkConfiguration = false;
        RoamRetryInterval = 10;
      };

      Network = {
        EnableIPv6 = false;
        RoutePriorityOffset = 300;
      };
    };
  };
}
