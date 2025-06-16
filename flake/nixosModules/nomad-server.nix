{moduleWithSystem, ...}: {
  flake.nixosModules.nomad-server = moduleWithSystem ({self'}: {
    lib,
    config,
    pkgs,
    ...
  }: let
    inherit (lib) mkForce;
  in {
    aws.instance.tags.Role = "cardano-perf-server";

    services.nomad = {
      enable = true;
      enableDocker = false;
      package = self'.packages.nomad;
      extraPackages = [pkgs.cni-plugins pkgs.nix];

      settings = {
        advertise = let
          mask = builtins.elemAt config.networking.wireguard.interfaces.wg0.ips 0;
          ip = lib.removeSuffix "/32" mask;
        in {
          http = ip;
          rpc = ip;
          serf = ip;
        };

        server = {
          enabled = true;
          bootstrap_expect = 1;
        };

        ui = {
          enabled = true;
          label.text = "Cardano Performance";
        };

        limits = {
          http_max_conns_per_client = 400;
          rpc_max_conns_per_client = 400;
        };
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
