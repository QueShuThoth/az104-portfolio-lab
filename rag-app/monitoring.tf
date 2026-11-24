# Session 26: Application Insights (workspace-based) for traces from the API, the worker
# and the function. Telemetry lands in the existing Log Analytics workspace.
#
# Keys off here too: local_authentication_enabled = false means the instrumentation key in
# the connection string can't send data by itself. Each app must also prove who it is with
# the managed identity, which needs the Monitoring Metrics Publisher role below.

resource "azurerm_application_insights" "rag" {
  name                         = "appi-rag-eus"
  location                     = azurerm_resource_group.rag.location
  resource_group_name          = azurerm_resource_group.rag.name
  workspace_id                 = azurerm_log_analytics_workspace.rag.id
  application_type             = "web"
  local_authentication_enabled = false # Entra ID ingestion only
  daily_data_cap_in_gb         = 1     # FinOps guard rail: a runaway loop can't send more than 1 GB a day
  tags                         = { project = "rag-app" }
}

# The app identity (API, worker and function all use it) may send telemetry
resource "azurerm_role_assignment" "app_monitoring_publisher" {
  scope                = azurerm_application_insights.rag.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

locals {
  # The connection string is marked sensitive by the provider. With local auth off it only
  # says where to send data (it can't send anything without the identity), so it's safe to
  # use in plain app settings.
  appi_connection_string = nonsensitive(azurerm_application_insights.rag.connection_string)
}

output "appinsights_name" {
  value = azurerm_application_insights.rag.name
}
