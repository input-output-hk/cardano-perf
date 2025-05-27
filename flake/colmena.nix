{
  inputs,
  config,
  lib,
  self,
  ...
}: let
  inherit (config.flake) nixosModules;
in {
  flake.colmena = let
    mkNode = name: wgIp: imports: {
      "${name}" = {
        imports =
          [
            {
              networking.wireguard.interfaces.wg0.ips = ["${wgIp}/32"];
              deployment.targetHost = name;
              deployment.tags = lib.optional (lib.hasPrefix "client-" name) "nomad-client";
            }
          ]
          ++ imports;
      };
    };

    mkNodeN = nameFormat: wgIpFormat: imports: n: let
      n' = n + 1;
      fixed2 = lib.fixedWidthNumber 2 n';
      replace = lib.replaceStrings ["%02d" "%d"] [fixed2 (toString n')];
      name = replace nameFormat;
      wgIp = replace wgIpFormat;
    in
      mkNode name wgIp imports;

    mkNodes = count: nameFormat: wgIpFormat: imports:
      lib.foldl' lib.recursiveUpdate {} (
        lib.genList (mkNodeN nameFormat wgIpFormat imports) count
      );

    eu-central-1b.aws = {
      region = "eu-central-1";
      instance.availability_zone = "eu-central-1b";
      instance.count = 1;
    };

    eu-central-1c.aws = {
      region = "eu-central-1";
      instance.availability_zone = "eu-central-1c";
      instance.count = 1;
    };

    us-east-1d.aws = {
      region = "us-east-1";
      instance.availability_zone = "us-east-1d";
      instance.count = 1;
    };

    ap-southeast-2b.aws = {
      region = "ap-southeast-2";
      instance.availability_zone = "ap-southeast-2b";
      instance.count = 1;
    };

    type = name: {aws.instance.instance_type = name;};

    nixos-23-05.system.stateVersion = "23.05";

    ebs = size: {aws.instance.root_block_device.volume_size = lib.mkDefault size;};

    mkClass = name: {
      services.nomad.settings.client.node_class = name;
      services.nomad.settings.client.meta.${name} = true;
      deployment.tags = [name];
      aws.instance.tags.Class = name;
    };

    perf-class = mkClass "perf";

    inherit (nixosModules) common nomad-client nomad-server deployer nix-private;
  in
    {
      meta.nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
      defaults.imports = [common nixos-23-05];
    }
    # change when we have an actual SSD
    # // (mkNodes 1 "client-ssd-eu-%02d" "10.200.21.%d" [(type "r5.4xlarge") nomad-client nomad-ssd perf-ssd-class (ebs 128) eu-central-1b])
    # // (mkNodes 1 "client-ssd-us-%02d" "10.200.22.%d" [(type "r5d.4xlarge") nomad-client nomad-ssd perf-ssd-class (ebs 128) eu-central-1b])
    // (mkNode "leader" "10.200.0.1" [eu-central-1c (type "r5.xlarge") nomad-server (ebs 40)])
    // (mkNode "deployer" "10.200.0.2" [eu-central-1b (type "c5.9xlarge") deployer nix-private (ebs 2000)])
    // (mkNode "explorer" "10.200.1.19" [eu-central-1b (type "m5.4xlarge") nomad-client perf-class (ebs 40)])
    # // (mkNodes 19 "client-ssd-eu-%02d" "10.200.21.%d" [(type "r5d.4xlarge") nix-private nomad-client nomad-ssd perf-ssd-class (ebs 40) eu-central-1b])
    # // (mkNodes 17 "client-ssd-ap-%02d" "10.200.22.%d" [(type "r5d.4xlarge") nix-private nomad-client nomad-ssd perf-ssd-class (ebs 40) ap-southeast-2b])
    # // (mkNodes 17 "client-ssd-us-%02d" "10.200.23.%d" [(type "r5d.4xlarge") nix-private nomad-client nomad-ssd perf-ssd-class (ebs 40) us-east-1d])
    // (mkNodes 18 "client-eu-%02d" "10.200.1.%d" [(type "c5.2xlarge") nomad-client perf-class (ebs 40) eu-central-1b])
    // (mkNodes 17 "client-ap-%02d" "10.200.2.%d" [(type "c5.2xlarge") nomad-client perf-class (ebs 40) ap-southeast-2b])
    // (mkNodes 17 "client-us-%02d" "10.200.3.%d" [(type "c5.2xlarge") nomad-client perf-class (ebs 40) us-east-1d]);

  flake.colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
}
