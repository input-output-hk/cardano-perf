flake: {
  perSystem = {
    lib,
    pkgs,
    config,
    inputs',
    self',
    ...
  }: {
    devShells.default = let
      inherit (flake.config.flake) cluster;
    in
      pkgs.mkShell {
        packages = with pkgs; [
          age
          awscli2
          deadnix
          inputs'.colmena.packages.colmena
          just
          nushell
          rain
          self'.packages.opentofu
          sops
          statix
          wireguard-tools
          self'.packages.nomad
        ];

        shellHook = ''
          ln -sf ${lib.getExe self'.packages.pre-push} .git/hooks/
          ln -sf ${config.treefmt.build.configFile} treefmt.toml
        '';

        SSH_CONFIG_FILE = ".ssh_config";
        KMS = cluster.kms;
        AWS_REGION = cluster.region;
        AWS_PROFILE = cluster.profile;
      };
  };
}
