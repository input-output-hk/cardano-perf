parts @ {
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.common = moduleWithSystem ({
    inputs',
    self',
  }: {
    name,
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = [
      parts.config.flake.nixosModules.wireguard
      parts.config.flake.nixosModules.aws-ec2
      inputs.sops-nix.nixosModules.default
      inputs.auth-keys-hub.nixosModules.auth-keys-hub
    ];

    networking = {
      hostName = name;
      firewall = {
        enable = true;
        allowedTCPPorts = [22 80 443 32000];
        allowedTCPPortRanges = [
          {
            from = 30000;
            to = 30052;
          }
        ];
      };
    };

    time.timeZone = "UTC";
    i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "en_US/ISO-8859-1"];

    boot = {
      tmp.cleanOnBoot = true;
      kernelParams = ["boot.trace"];
      loader.grub.configurationLimit = 10;
    };

    # On boot SOPS runs in stage 2 without networking.
    # For repositories using KMS sops secrets, this prevent KMS from working,
    # so we repeat the activation script until decryption succeeds.
    #
    # Sops-nix module does provide a systemd restart and reload hook for
    # associated secrets changes with the option:
    #
    #   sops.secrets.<name>.<restartUnits|reloadUnits>
    #
    # Although the sops-nix restart or reload options are preferred,
    # sops-secrets service can also act as a generic systemd hook
    # for services needing to be restarted after new sops secrets are pushed.
    #
    # Example usage:
    #   systemd.services.<name> = {
    #     after = ["sops-secrets.service"];
    #     wants = ["sops-secrets.service"];
    #     partOf = ["sops-secrets.service"];
    #   };
    #
    systemd.services.sops-secrets = lib.mkIf (config.system.activationScripts.setupSecrets ? text) {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];

      script = config.system.activationScripts.setupSecrets.text;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

    documentation = {
      nixos.enable = false;
      man.man-db.enable = false;
      info.enable = false;
      doc.enable = false;
    };

    environment.systemPackages = with pkgs; [
      awscli2
      bat
      bind
      di
      dnsutils
      duf
      fd
      file
      git
      glances
      graphviz
      helix
      htop
      iptables
      jq
      lsof
      mosh
      nano
      ncdu
      pciutils
      ripgrep
      rsync
      self'.packages.go-discover
      sops
      sysstat
      tcpdump
      tig
      tree
      cloud-utils
      parted
    ];

    programs = {
      sysdig.enable = true;
      mosh.enable = true;

      tmux = {
        enable = true;
        aggressiveResize = true;
        clock24 = true;
        escapeTime = 0;
        historyLimit = 10000;
        newSession = true;
      };

      auth-keys-hub = {
        enable = true;
        package = inputs'.auth-keys-hub.packages.auth-keys-hub;
        github = {
          users = ["sgillespie"];
          teams = [
            "input-output-hk/performance-tracing"
            "input-output-hk/node-sre"
          ];

          tokenFile = config.sops.secrets.github-token.path;
        };
      };
    };

    sops.defaultSopsFormat = "binary";
    sops.secrets.github-token = {
      sopsFile = "${self}/secrets/github-token.enc";
      owner = config.programs.auth-keys-hub.user;
      inherit (config.programs.auth-keys-hub) group;
    };

    services = {
      chrony.enable = true;
      cron.enable = true;
      fail2ban.enable = true;
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          RequiredRSASize = 2048;
          PubkeyAcceptedAlgorithms = "-*nist*";
        };
      };
    };

    users.mutableUsers = false;

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBbtFrxN6W8MK2e0fDVHVrcgC5ILBitN63wvsIPdUEdB pt-team@perf"
    ];

    system.extraSystemBuilderCmds = ''
      ln -sv ${pkgs.path} $out/nixpkgs
    '';

    nix = {
      registry.nixpkgs.flake = inputs.nixpkgs;
      optimise.automatic = false;
      gc.automatic = false;

      settings = {
        fallback = true;
        max-jobs = "auto";
        experimental-features = ["nix-command" "flakes" "cgroups"];
        auto-optimise-store = true;
        system-features = ["recursive-nix" "nixos-test"];
        substituters = ["https://cache.iog.io"];
        trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
        builders-use-substitutes = true;
        show-trace = true;
        keep-outputs = true;
        keep-derivations = true;
        tarball-ttl = 60 * 60 * 72;
      };
    };

    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
    };

    hardware = {
      cpu.amd.updateMicrocode = true;
      enableRedistributableFirmware = true;
    };
  });
}
