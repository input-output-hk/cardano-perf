parts: {
  flake.nixosModules.deployer = {
    config,
    pkgs,
    ...
  }: {
    imports = [parts.config.flake.nixosModules.serve-runs];

    aws.instance.tags.Role = "deployer";

    # NOTE: This block device needs to be manually labelled non-destructively
    # only once so that the block device can be reproducibly remounted on each
    # reboot.  Otherwise, if the /dev/nvme* path is used to try and mount, it
    # will randomly break on reboot as AWS non-deterministically assigns block
    # device names.
    #
    # The command to check the label is:
    #
    #   blkid | grep devfs
    #
    # The command to create a label if no label exists is:
    #
    #   e2label /dev/$DEVICE devfs
    #
    # Once labelled, the following declaration will reproducibly mount:
    fileSystems."/home" = {
      device = "/dev/disk/by-label/devfs";
      fsType = "ext4";
      autoFormat = true;
      autoResize = true;
    };

    swapDevices = [
      {
        device = "/home/swapfile";
        size = 32 * 1024;
        discardPolicy = "both";
      }
    ];

    systemd.services.mkfs-dev-sdh.after = ["multi-user.target"];

    services.openssh.settings.MaxStartups = "64:30:100";

    environment.systemPackages = with pkgs; [
      (ruby.withPackages (ps: with ps; [sequel pry sqlite3 nokogiri]))
      screen
      sqlite-interactive
      tmux
      gnupg
      pinentry
    ];

    users.users.dev = {
      isNormalUser = true;
      createHome = true;
    };

    programs = {
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      mosh.enable = true;

      screen.screenrc = ''
        autodetach on
        bell "%C -> %n%f %t Bell!~"
        bind .
        bind \\
        bind ^\
        bind e mapdefault
        crlf off
        defmonitor on
        defscrollback 1000
        defscrollback 10000
        escape ^aa
        hardcopy_append on
        hardstatus alwayslastline "%{b}[ %{B}%H %{b}][ %{w}%?%-Lw%?%{b}(%{W}%n*%f %t%?(%u)%?%{b})%{w}%?%+Lw%?%?%= %{b}][%{B} %Y-%m-%d %{W}%c %{b}]"
        maptimeout 5
        msgwait 2
        pow_detach_msg "BYE"
        shelltitle "Shell"
        silencewait 15
        sorendition gk #red on white
        startup_message off
        vbell_msg " *beep* "
        vbell off
      '';
    };

    nix = {
      nrBuildUsers = 36;
      settings.system-features = ["recursive-nix" "nixos-test" "benchmark"];
      settings.secret-key-files = [config.sops.secrets.nix-signing-key.path];

      sshServe = {
        enable = true;
        protocol = "ssh-ng";
        keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9jutPzEgNOVqyJzsat9yu1Ie2vESIcgHXLH5z41nAx nix-ssh@cardano-perf"];
      };
    };

    sops.secrets.nix-signing-key = {
      sopsFile = ../../secrets/nix-signing-key.enc;
      restartUnits = ["nix-daemon.service"];
    };
  };
}
