# Session 20: Container Apps environment + the API app, with one user-assigned managed identity.
# Session 21: multiple-revision mode, revisions named after the image tag (ca-rag-api--v2),
#             and traffic splits set with the Azure CLI.
# Session 25: the API reads its settings from App Configuration (APPCONFIG_ENDPOINT).
# The environment and the identity are free on their own. The app sits behind enable_registry,
# because it needs the image in the registry.

variable "api_image_tag" {
  description = "Image tag the API runs (built with az acr build)"
  type        = string
  default     = "v1"
}

# One identity for every app in this project (API now, worker and function later)
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-rag-app-eus"
  location            = azurerm_resource_group.rag.location
  resource_group_name = azurerm_resource_group.rag.name
  tags                = { project = "rag-app" }
}

# What the identity may do. No keys or passwords anywhere.
resource "azurerm_role_assignment" "app_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_cosmosdb_sql_role_assignment" "app_data_contributor" {
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
  role_definition_id  = "${azurerm_cosmosdb_account.rag.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.app.principal_id
  scope               = azurerm_cosmosdb_account.rag.id
}

resource "azurerm_role_assignment" "app_acr_pull" {
  count                = var.enable_registry ? 1 : 0
  scope                = azurerm_container_registry.rag[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# Workload profiles environment with only the free-to-idle Consumption profile.
# No VNet yet: Session 29 recreates it inside Spoke 1.
resource "azurerm_container_app_environment" "rag" {
  name                       = "cae-rag-app-eus"
  location                   = azurerm_resource_group.rag.location
  resource_group_name        = azurerm_resource_group.rag.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.rag.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = { project = "rag-app" }

  lifecycle {
    # Azure names the managed infrastructure group itself; don't let that force a rebuild
    ignore_changes = [infrastructure_resource_group_name]
  }
}

resource "azurerm_container_app" "api" {
  count                        = var.enable_registry ? 1 : 0
  name                         = "ca-rag-api"
  container_app_environment_id = azurerm_container_app_environment.rag.id
  resource_group_name          = azurerm_resource_group.rag.name
  revision_mode                = "Multiple" # Session 21: old revisions stay, so traffic can be split
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  # Pull from ACR with the managed identity (AcrPull), not a password
  registry {
    server   = azurerm_container_registry.rag[0].login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    # Revision name = ca-rag-api--<tag>. A new tag means a new revision.
    # Every change to this template needs a new image tag, or Azure rejects the duplicate suffix.
    revision_suffix = replace(var.api_image_tag, ".", "-")

    min_replicas = 0 # scale to zero when idle: no requests, no bill
    max_replicas = 2

    container {
      name   = "api"
      image  = "${azurerm_container_registry.rag[0].login_server}/rag-api:${var.api_image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "OPENAI_ENDPOINT"
        value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com"
      }
      env {
        name  = "COSMOS_ENDPOINT"
        value = azurerm_cosmosdb_account.rag.endpoint
      }
      env {
        # Tells DefaultAzureCredential which identity to use inside the container
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.app.client_id
      }
      env {
        # Session 25: where the API loads chat_model, top_k and the admin key from
        name  = "APPCONFIG_ENDPOINT"
        value = azurerm_app_configuration.rag.endpoint
      }
    }
  }

  tags = { project = "rag-app" }

  # The identity must be allowed to pull before the first revision starts,
  # and (Session 25) to read App Configuration and Key Vault when a new revision starts
  depends_on = [
    azurerm_role_assignment.app_acr_pull,
    azurerm_role_assignment.app_appconfig_reader,
    azurerm_role_assignment.app_kv_secrets_user,
  ]

  lifecycle {
    # Traffic splits are set with az containerapp ingress traffic set (Session 21).
    # Terraform leaves them alone instead of resetting them on every apply.
    ignore_changes = [ingress[0].traffic_weight]
  }
}

output "api_url" {
  value = try("https://${azurerm_container_app.api[0].ingress[0].fqdn}", null)
}
