terraform {
  required_version = ">= 1.11"

  # State lives in vump-platform-tfstate, created by one-off CLI calls documented
  # in ../../README.md. It cannot be created by the configuration that stores its
  # state in it, so it is a deliberate manual prerequisite rather than an omission.
  #
  # use_lockfile is S3-native locking. It replaces the DynamoDB lock table the S3
  # backend used to require — one less resource to provision and to pay for.
  backend "s3" {
    bucket       = "vump-platform-tfstate"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
