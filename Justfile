set shell := ["nu", "-c"]
set positional-arguments

default:
  just --list

apply-all:
  colmena apply --verbose

apply *ARGS:
  colmena apply --verbose --on {{ARGS}}

ssh HOSTNAME *ARGS:
  #!/usr/bin/env nu
  if not ('.ssh_config' | path exists) {
    print "Please run terraform first to create the .ssh_config file"
    exit 1
  }

  ssh -F .ssh_config {{HOSTNAME}} {{ARGS}}

ssh-for-each *ARGS:
  #!/usr/bin/env nu
  let nodes = (nix eval --json '.#nixosConfigurations' --apply builtins.attrNames | from json)
  for node in $nodes { just ssh $node {{ARGS}} }

bootstrap-ssh HOSTNAME *ARGS:
  #!/usr/bin/env nu
  if not ('.ssh_config' | path exists) {
    print "Please run terraform first to create the .ssh_config file"
    exit 1
  }

  if not ('.ssh_key' | path exists) {
    just save-bootstrap-ssh-key
  }

  ssh -F .ssh_config -i .ssh_key {{HOSTNAME}} {{ARGS}}

save-bootstrap-ssh-key:
  #!/usr/bin/env nu
  print "Retrieving ssh key from terraform..."
  let tf = (terraform show -json | from json)
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

terraform *ARGS:
  rm --force cluster.tf.json
  nix build .#terraform.cluster --out-link cluster.tf.json
  terraform {{ARGS}}

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

alias tf := terraform

lint:
  deadnix -f
  statix check

nomad-ui:
  #!/usr/bin/env nu
  print "Nomad will be available at http://127.0.0.1:4646"
  ssh -F .ssh_config -N -L 4646:leader:4646 leader
