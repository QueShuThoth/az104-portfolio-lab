# Session 15: resource group, Log Analytics, Foundry resource, two model deployments

# Who is running Terraform (your signed-in az account). Used for the role assignment.
data "azurerm_client_config" "current" {}

# Short random suffix, because the Foundry subdomain must be unique across all of Azure
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rag" {
  name     = "rg-rag-app-eus"
  location = var.location
  tags     = { project = "rag-app" }
}

# Logs land here later (Container Apps, in a later session). Free while nothing sends data.
resource "azurerm_log_analytics_workspace" "rag" {
  name                = "log-rag-app-eus"
  location            = azurerm_resource_group.rag.location
  resource_group_name = azurerm_resource_group.rag.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = { project = "rag-app" }
}

# Foundry resource (kind AIServices). Keys are switched off: Entra ID only.
resource "azurerm_cognitive_account" "foundry" {
  name                  = "ais-rag-eus-${random_string.suffix.result}"
  location              = azurerm_resource_group.rag.location
  resource_group_name   = azurerm_resource_group.rag.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = "ais-rag-eus-${random_string.suffix.result}" # needed for Entra ID sign-in
  local_auth_enabled    = false                                        # no API keys
  tags                  = { project = "rag-app" }
}

# Chat model. Global Standard bills per token only; capacity is a rate limit (10 = 10K tokens/min).
resource "azurerm_cognitive_deployment" "chat" {
  name                 = "gpt-5-mini"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = "gpt-5-mini"
    version = "2025-08-07"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

# Embedding model (turns text into vectors for search later)
resource "azurerm_cognitive_deployment" "embed" {
  name                 = "text-embedding-3-small"
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-small"
    version = "1"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }

  # One deployment at a time on the same resource, or Azure can reject the second
  depends_on = [azurerm_cognitive_deployment.chat]
}

# Let YOU call the models with your Entra ID sign-in (Owner alone can't call them)
resource "azurerm_role_assignment" "me_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = data.azurerm_client_config.current.object_id
}
