import? 'scripts/recipes-aws.just'

set shell := ["nu", "-c"]
set positional-arguments

default:
  just --list

# Deploy select machines
apply *ARGS:
  colmena apply --verbose --experimental-flake-eval --nix-option accept-flake-config true --on {{ARGS}}

# Deploy all machines
apply-all *ARGS:
  colmena apply --verbose --experimental-flake-eval --nix-option accept-flake-config true {{ARGS}}

ssh HOSTNAME *ARGS:
  #!/usr/bin/env nu
  if not ('.ssh_config' | path exists) {
    print "Please run tofu first to create the .ssh_config file"
    exit 1
  }

  ssh -F .ssh_config {{HOSTNAME}} {{ARGS}}

ssh-for-all *ARGS:
  #!/usr/bin/env nu
  let nodes = (nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | from json)
  $nodes | par-each {|node| just ssh -q $node {{ARGS}} }

ssh-for-each HOSTNAMES *ARGS:
  colmena exec --verbose --experimental-flake-eval --parallel 0 --nix-option accept-flake-config true --on {{HOSTNAMES}} {{ARGS}}

gc-all:
  #!/usr/bin/env nu
  # let nodes = (nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | from json | filter {|node| $node != "deployer" })
  let nodes = (nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | from json | filter {|node| $node == "leader" })
  $nodes | par-each {|node| {$node: (just ssh $node -q di -h -n -I ext4)} } | reduce {|a,b| $a | merge $b } | save --force gc_all_before.json
  $nodes | par-each {|node| {$node: (just ssh $node -q di -h -n -I ext4)} } | reduce {|a,b| $a | merge $b } | save --force gc_all_after.json

  # $nodes | par-each {|node| just ssh -q $node nix-collect-garbage --delete-older-than 30d }
bootstrap-ssh HOSTNAME *ARGS:
  #!/usr/bin/env nu
  if not ('.ssh_config' | path exists) {
    print "Please run tofu first to create the .ssh_config file"
    exit 1
  }

  if not ('.ssh_key' | path exists) {
    just save-bootstrap-ssh-key
  }

  ssh -F .ssh_config -i .ssh_key {{HOSTNAME}} {{ARGS}}

save-bootstrap-ssh-key:
  #!/usr/bin/env nu
  print "Retrieving ssh key from tofu..."
  let tf = (tofu show -json | from json)
  let key = ($tf.values.root_module.resources | where type == tls_private_key and name == bootstrap)
  $key.values.private_key_openssh | save .ssh_key
  chmod 0600 .ssh_key

cf STACKNAME:
  mkdir cloudFormation
  nix eval --json '.#cloudFormation.{{STACKNAME}}' | from json | save --force 'cloudFormation/{{STACKNAME}}.json'
  rain deploy --debug --termination-protection --yes ./cloudFormation/{{STACKNAME}}.json

wg-genkey KMS HOSTNAME:
  #!/usr/bin/env nu
  let private = 'secrets/wireguard_{{HOSTNAME}}.enc'
  let public = 'secrets/wireguard_{{HOSTNAME}}.txt'

  if not ($private | path exists) {
    print $"Generating ($private) ..."
    wg genkey | sops --kms "{{KMS}}" -e /dev/stdin | save $private
    git add $private
  }

  if not ($public | path exists) {
    print $"Deriving ($public) ..."
    sops -d $private | wg pubkey | save $public
    git add $public
  }

wg-genkeys:
  #!/usr/bin/env nu
  let kms = (nix eval --raw '.#cluster.kms')
  let nodes = (nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | from json)
  for node in $nodes { just wg-genkey $kms $node }

tf *ARGS:
  rm --force cluster.tf.json
  nix build .#terraform.cluster --out-link cluster.tf.json
  tofu {{ARGS}}

show-nameservers:
  #!/usr/bin/env nu
  let domain = (nix eval --raw '.#cluster.domain')
  let zones = (aws route53 list-hosted-zones-by-name | from json).HostedZones
  let id = ($zones | where Name == $"($domain).").Id.0
  let sets = (aws route53 list-resource-record-sets --hosted-zone-id $id | from json).ResourceRecordSets
  let ns = ($sets | where Type == "NS").ResourceRecords.0.Value
  print "Nameservers for the following hosted zone need to be added to the NS record of the delegating authority"
  print $"Nameservers for domain: ($domain) \(hosted zone id: ($id)) are:"
  print ($ns | to text)

lint:
  deadnix -f
  statix check

nomad-ui:
  @echo "Nomad will be available at http://127.0.0.1:4646"
  ssh -F .ssh_config -N -L 4646:leader:4646 leader

# List machines in the cluster
ls:
  #!/usr/bin/env nu
  let nix = (
    nix eval '.#nixosConfigurations'
      --json
      --apply 'n: (map (n: {name=n; in_nixos_conf = true;}) (builtins.attrNames n))'
      | from json
      | dfr into-df
  )

  let list = (
    just tf show -json
    | from json
    | get values.root_module.resources
    | where type == "aws_instance"
    | each {|n|
        {
          name: $n.name,
          public_ip: $n.values.public_ip,
          private_ip: $n.values.private_ip
        }
      }
    | dfr into-df
    | dfr join --outer $nix name name
    | dfr sort-by name
  )

  $list | dfr into-nu

save-ssh-config:
  #!/usr/bin/env nu
  print "Retrieving ssh config from tofu..."
  nix build ".#terraform.cluster" --out-link cluster.tf.json
  tofu workspace select -or-create default
  let tf = (tofu show -json | from json)
  let key = ($tf.values.root_module.resources | where type == local_file and name == ssh_config)
  $key.values.content | save --force $env.SSH_CONFIG_FILE
  chmod 0600 $env.SSH_CONFIG_FILE
  print $"Saved to ($env.SSH_CONFIG_FILE)"
