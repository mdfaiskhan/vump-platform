output "invoke_url" {
  description = <<-EOT
    Base URL of the deployed stage.

    Deferred item 1 records that the mobile client's base URLs are placeholders
    on the reserved `.example` TLD. This is the real value for development; the
    client change belongs to the mission that owns ADR-007's NetworkConfig.
  EOT
  value       = aws_api_gateway_stage.this.invoke_url
}

output "rest_api_id" {
  description = "REST API id."
  value       = aws_api_gateway_rest_api.this.id
}

output "function_names" {
  description = "Deployed Lambda function names, keyed by ADR-015 function."
  value       = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "routes" {
  description = "Every route this API serves, as `METHOD /path` — the same strings the handlers route on."
  value       = sort([for r in local.routes : "${r.method} ${r.path}"])
}
