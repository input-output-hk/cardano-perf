{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.aws-ec2 = {
    lib,
    name,
    ...
  }: {
    imports = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
    ];

    options = {
      aws = lib.mkOption {
        default = null;
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            region = lib.mkOption {
              type = lib.types.str;
              default = self.cluster.infra.aws.region;
            };

            instance = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  count = lib.mkOption {
                    type = lib.types.int;
                    default = 1;
                  };

                  instance_type = lib.mkOption {
                    type = lib.types.str;
                  };

                  root_block_device = lib.mkOption {
                    type = lib.types.attrs;
                  };

                  availability_zone = lib.mkOption {
                    type = lib.types.str;
                  };

                  tags = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                  };
                };
              };
            };

            aws_route53_record = lib.mkOption {
              default = [];
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    zone_id = lib.mkOption {
                      type = lib.types.str;
                      default = "\${data.aws_route53_zone.selected.zone_id}";
                    };
                    name = lib.mkOption {
                      type = lib.types.str;
                    };
                    type = lib.mkOption {
                      type = lib.types.str;
                      default = "A";
                    };
                    ttl = lib.mkOption {
                      type = lib.types.str;
                      default = "300";
                    };
                    records = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = ["\${aws_eip.${name}[0].public_ip}"];
                    };
                  };
                }
              );
            };
          };
        });
      };
    };

    config = {
      aws.instance.tags = {
        inherit (self.cluster.generic) organization tribe function repo;
        environment = name;
        group = name;
        Name = name;
      };

      aws.aws_route53_record = [
        {
          zone_id = "\${data.aws_route53_zone.selected.zone_id}";
          name = "${name}.\${data.aws_route53_zone.selected.name}";
          type = "A";
          ttl = "300";
          records = ["\${aws_eip.${name}[0].public_ip}"];
        }
      ];
    };
  };
}
