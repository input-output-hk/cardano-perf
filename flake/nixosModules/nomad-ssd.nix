{
  flake.nixosModules.nomad-ssd = {
    nix.settings.system-features = ["benchmark"];

    services.nomad.settings.client.host_volume = {
      "ephemeral".path = "/dev/ephemeral";
    };

    # NOTE: the simple nixos fileSystems approach below won't work because upon
    # reboot, instances with ephemeral disks will randomly re-assign the device
    # names between gp2/gp3/ephemeral leading to mount failure.
    #
    # The solution for this is to use the nixosModule `ephemeral`.
    #
    # fileSystems = {
    #   "/ssd1" = {
    #     device = "/dev/nvme1n1";
    #     fsType = "ext2";
    #     autoFormat = true;
    #     options = ["noatime" "nodiratime" "noacl"];
    #   };
    # };
  };
}
