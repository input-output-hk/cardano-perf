{self, ...} @ flake: {
  flake.nixosModules.wireguard = {
    config,
    lib,
    name,
    nodes,
    pkgs,
    ...
  }: {
    sops.secrets.wg = {
      sopsFile = "${self}/secrets/wireguard_${name}.enc";
      restartUnits = ["wireguard-wg0.service"];
    };

    systemd.services.wireguard-wg0 = {
      after = ["sops-nix.service"];
      serviceConfig = {
        ExecStartPre = lib.getExe (pkgs.writeShellApplication {
          name = "wait-for-sops-key";
          runtimeInputs = [];
          text = ''
            while true; do
              if [ -f ${config.sops.secrets.wg.path} ]; then
                echo "Found ${config.sops.secrets.wg.path}..."
                break
              fi
              echo "Sleeping 2 seconds to wait for sops secrets..."
              sleep 2
            done
          '';
        });

        SupplementaryGroups = [config.users.groups.keys.name];
      };
    };

    networking = {
      firewall = {
        allowedUDPPorts = [config.networking.wireguard.interfaces.wg0.listenPort];
        interfaces.wg0 = {
          allowedTCPPorts = [22 80 443 4646 4647];
          allowedUDPPorts = [4648];
        };
      };

      wireguard = {
        enable = true;

        interfaces.wg0 = {
          privateKeyFile = lib.mkDefault config.sops.secrets.wg.path;
          listenPort = 51820;

          # Use a star topology with leader (nomad server) as the hub to minimize uneeded network traffic
          peers = let
            mkPeer = nodeName: node: {
              name = nodeName;
              allowedIPs = node.config.networking.wireguard.interfaces.wg0.ips;
              endpoint = "${nodeName}.${flake.config.flake.cluster.domain}:51820";
              publicKey = lib.fileContents "${self}/secrets/wireguard_${nodeName}.txt";
              persistentKeepalive = 25;
            };
          in
            if name == "leader"
            then
              [
                {
                  name = "fmaste";
                  allowedIPs = ["10.200.100.1/32"];
                  publicKey = "Kb5WEHzkEpHVgD5OasHT6XsmZknGraXH50XbQ8Qdcys=";
                  persistentKeepalive = 25;
                }
              ]
              ++ (lib.mapAttrsToList mkPeer (removeAttrs nodes [name]))
            else [(mkPeer "leader" nodes.leader)];
        };
      };
    };
  };
}
