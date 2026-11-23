# Session 25: App Configuration (Free) for settings + Key Vault (RBAC) for the one secret.
# Both have no idle charge, so they aren't behind a switch.
#
# Terraform builds the stores and the permissions. The values themselves (settings and the
# secret) are set with the Azure CLI in the steps, so the secret never lands in tfstate.

resource "azurerm_key_vault" "rag" {
  name                       = "kv-rag-eus-${random_string.suffix.result}"
  location                   = azurerm_resource_group.rag.location
  resource_group_name        = azurerm_resource_group.rag.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id # read at plan time, never typed
  sku_name                   = "standard"
  rbac_authorization_enabled = true  # Azure roles, not old-style access policies
  soft_delete_retention_days = 7     # the minimum
  purge_protection_enabled   = false # lab: lets end-of-day destroy purge it cleanly
  tags                       = { project = "rag-app" }
}

# You: create and rotate secrets from the CLI
resource "azurerm_role_assignment" "me_kv_secrets_officer" {
  scope                = azurerm_key_vault.rag.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The app identity: read secret values, nothing else
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.rag.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_app_configuration" "rag" {
  name                = "appcs-rag-eus-${random_string.suffix.result}"
  location            = azurerm_resource_group.rag.location
  resource_group_name = azurerm_resource_group.rag.name
  sku                 = "free" # 1 free store per subscription, 1,000 requests a day
  local_auth_enabled  = false  # no access keys or connection strings: Entra ID only
  tags                = { project = "rag-app" }
}

# You: write settings from the CLI
resource "azurerm_role_assignment" "me_appconfig_owner" {
  scope                = azurerm_app_configuration.rag.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The app identity: read settings only
resource "azurerm_role_assignment" "app_appconfig_reader" {
  scope                = azurerm_app_configuration.rag.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

output "key_vault_name" {
  value = azurerm_key_vault.rag.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.rag.vault_uri
}

output "appconfig_endpoint" {
  value = azurerm_app_configuration.rag.endpoint
}
