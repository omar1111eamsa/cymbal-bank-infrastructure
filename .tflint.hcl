# Shared TFLint config for every stack under terraform/
config {
  call_module_type = "local" # also lint our own local modules
}

# Generic Terraform hygiene: unused vars, missing versions, naming
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-aware rules: invalid instance types, regions, deprecated args
plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
