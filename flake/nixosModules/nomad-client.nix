{moduleWithSystem, ...}: {
  flake.nixosModules.nomad-client = moduleWithSystem ({self'}: {
    nodes,
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (lib) mkForce;
  in {
    aws.instance.tags.Role = "cardano-perf-client";

    services.nomad = {
      enable = true;
      enableDocker = false;
      dropPrivileges = false;
      package = self'.packages.nomad;
      extraPackages = [pkgs.cni-plugins pkgs.nix];

      settings = {
        datacenter = config.aws.region;

        client = {
          enabled = true;
          network_interface = "wg0";

          server_join = {
            retry_join = [(lib.removeSuffix "/32" (builtins.elemAt nodes.leader.config.networking.wireguard.interfaces.wg0.ips 0))];
            retry_max = 60;
            retry_interval = "15s";
          };
        };

        consul = {
          client_auto_join = false;
          auto_advertise = false;
        };

        plugin = [
          {
            raw_exec = [
              {
                config = [
                  {
                    enabled = true;
                    no_cgroups = true;
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    # This will allow the service to continue retrying until sops keys are in
    # place, wireguard is up and running and the ephemeral volumes, if any, are
    # mounted.
    systemd.services.nomad = {
      serviceConfig = {
        Restart = mkForce "always";
        RestartSec = mkForce 10;
      };

      unitConfig = {
        StartLimitIntervalSec = mkForce 0;
        StartLimitBurst = mkForce 0;
      };
    };
  });
}
