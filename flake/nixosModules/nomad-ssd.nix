{
  flake.nixosModules.nomad-ssd = {
    # Begin Remove when tooling is multi-cluster
    users.users.shlevy = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/fJqgjwPG7b5SRPtCovFmtjmAksUSNg3xHWyqBM4Cs shlevy@shlevy-laptop"
      ];
    };
    nix.settings.system-features = [ "benchmark" ];
    # End Remove when tooling is multi-cluster

    services.nomad.settings.client.host_volume = {
      "ssd1".path = "/ssd1";
      "ssd2".path = "/ssd2";
      "ssd3".path = "/ssd3";
      "ssd4".path = "/ssd4";
    };

    fileSystems = {
      "/ssd1" = {
        device = "/dev/nvme1n1";
        fsType = "ext2";
        autoFormat = true;
      };

      "/ssd2" = {
        device = "/dev/nvme2n1";
        fsType = "ext2";
        autoFormat = true;
      };

      "/ssd3" = {
        device = "/dev/nvme3n1";
        fsType = "ext2";
        autoFormat = true;
      };

      "/ssd4" = {
        device = "/dev/nvme4n1";
        fsType = "ext2";
        autoFormat = true;
      };
    };
  };
}
