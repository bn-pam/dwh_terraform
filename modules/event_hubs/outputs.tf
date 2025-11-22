output "send_connection_string" {
  value     = azurerm_eventhub_namespace_authorization_rule.send_policy.primary_connection_string
  sensitive = true
}

output "listen_connection_string" {
  value     = azurerm_eventhub_namespace_authorization_rule.listen_policy.primary_key
  sensitive = true
}
