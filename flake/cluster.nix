{
  # Define some cluster-wide configuration.
  # This has to evaluate fast and is imported in various places.
  flake.cluster = rec {
    orgId = "634968354090";
    # We may need more than one key here?
    kms = "arn:aws:kms:${region}:${orgId}:alias/kmsKey";
    region = "eu-central-1";
    profile = "cardano-perf";

    # Set a region to false to set its count to 0 in terraform.
    # After applying once you can remove the line.
    regions = {
      us-east-1 = true;
      eu-central-1 = true;
      ap-southeast-2 = true;
    };

    domain = "perf.aws.iohkdev.io";
    bucketName = "cardano-perf-terraform";

    generic = {
      organization = "ioe";
      tribe = "coretech";
      function = "cardano-perf";
      repo = "https://github.com/input-output-hk/cardano-perf";

      # Tags below are required by IT/Finance
      owner = "ioe";
      environment = "benchmarking";
      project = "cardano-perf";

      # This is the tf var secrets name located in secrets/cluster.tfvars.enc
      costCenter = "tag_costCenter";
    };
  };
}
