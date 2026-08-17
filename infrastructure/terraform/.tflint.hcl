// TFLint configuration for infrastructure/terraform/.
//
// The bundled terraform ruleset covers naming, unused declarations and
// deprecated syntax. The aws plugin adds provider-specific checks — invalid
// instance classes, malformed ARNs, unsupported engine versions — which is the
// half that catches a plan that is syntactically fine and rejected by AWS.

config {
  call_module_type = "all"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
