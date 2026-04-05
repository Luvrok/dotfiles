{ ... }:

{
  imports = [
    ./network.nix
    ./wireless.nix
  ];

  networking = {
    useNetworkd = true;
    useDHCP = false;
    usePredictableInterfaceNames = true;
  };
}
