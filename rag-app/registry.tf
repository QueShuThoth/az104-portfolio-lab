# Session 19: container registry (Basic) for the API image. Behind the enable_registry switch.
# Admin user off: nothing logs in with a username and password. Container Apps pulls with
# its managed identity (AcrPull role, Session 20), and you push with az acr build.

resource "azurerm_container_registry" "rag" {
  count               = var.enable_registry ? 1 : 0
  name                = "acrrag${random_string.suffix.result}" # letters and numbers only, globally unique
  resource_group_name = azurerm_resource_group.rag.name
  location            = azurerm_resource_group.rag.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = { project = "rag-app" }
}

output "acr_name" {
  value = one(azurerm_container_registry.rag[*].name)
}

output "acr_login_server" {
  value = one(azurerm_container_registry.rag[*].login_server)
}
