{
  inputs,
  lib,
  ...
}:

let
  inherit (builtins)
    readFile
    ;
in
{
  name = "wifi";

  nodes = {
    airgap = { ... }: {
      _module.args = { inherit inputs; };
      imports = [
        #self.nixosModules.default
        #(import ./user/testA.nix {inherit inputs;})
      ];

      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.2";
          prefixLength = 24;
        }
      ];
      services.vwifi = {
        server = {
          enable = true;
          ports.tcp = 8212;
          # uncomment if you want to enable monitor mode on another node
          # ports.spy = 8213;
          openFirewall = true;
        };
      };
    };

    ap = { ... }: {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.3";
          prefixLength = 24;
        }
      ];
      services.hostapd = {
        enable = true;
        radios.wlan0 = {
          channel = 1;
          networks.wlan0 = {
            ssid = "NixOS Test Wi-Fi Network";
            authentication = {
              mode = "wpa3-sae";
              saePasswords = [ { password = "supersecret"; } ];
              enableRecommendedPairwiseCiphers = true;
            };
          };
        };
      };
      services.vwifi = {
        module = {
          enable = true;
          macPrefix = "74:F8:F6:00:01";
        };
        client = {
          enable = true;
          serverAddress = "192.168.1.2";
        };
      };
    };

    client = { ... }: {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.4";
          prefixLength = 24;
        }
      ];
      /*
        networking.wireless = {
          # No, really, we want it enabled!
          enable = lib.mkOverride 0 true;
          interfaces = [ "wlan0" ];
          networks = {
            "NixOS Test Wi-Fi Network" = {
              psk = "supersecret";
              authProtocols = [ "SAE" ];
            };
          };
        };
      */
      networking.networkmanager.enable = true;
      services.vwifi = {
        module = {
          enable = true;
          macPrefix = "74:F8:F6:00:02";
        };
        client = {
          enable = true;
          serverAddress = "192.168.1.2";
        };
      };
    };
  };

  testScript = readFile ./check/wifi.py;
}
