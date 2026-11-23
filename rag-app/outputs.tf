output "foundry_name" {
  value = azurerm_cognitive_account.foundry.name
}

output "openai_endpoint" {
  value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com"
}
