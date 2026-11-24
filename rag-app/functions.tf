# Session 24: an Azure Function on the Flex Consumption plan with a Cosmos DB trigger.
# Every time chunks change in "chunks", the change feed wakes the function, which writes
# (or skips) a short per-document summary into a "summaries" container.
#
# Not behind a switch: Flex Consumption has no idle charge (no always-ready instances),
# and its monthly free grant covers a lab easily. The new Cosmos database uses 400 of the
# free tier's 1000 RU/s (chunks already uses 400), so Cosmos stays free too.
#
# Why azapi for the function app itself: azurerm's azurerm_function_app_flex_consumption
# (as of 4.81) writes a key-based AzureWebJobsStorage setting even when you choose a
# managed identity, which breaks a storage account with Shared Key off, and its workaround
# leaves a change in every plan. azapi sends exactly what Microsoft's own Bicep sample sends.
#
# Session 26: two new app settings send the function's logs to Application Insights,
# signed in with the managed identity (AAD) because local auth is off.

# ---------- Cosmos DB: leases + summaries, sharing 400 RU/s ----------

resource "azurerm_cosmosdb_sql_database" "feed" {
  name                = "ragfeed"
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
  throughput          = 400 # shared by every container in this database
}

# The trigger's bookmark: which changes it has already processed.
# Created here because a managed identity isn't allowed to create containers.
resource "azurerm_cosmosdb_sql_container" "leases" {
  name                = "leases"
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
  database_name       = azurerm_cosmosdb_sql_database.feed.name
  partition_key_paths = ["/id"] # the Functions trigger requires /id for leases
}

resource "azurerm_cosmosdb_sql_container" "summaries" {
  name                = "summaries"
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
  database_name       = azurerm_cosmosdb_sql_database.feed.name
  partition_key_paths = ["/source"] # one summary per document, same key as chunks
}

# ---------- Host storage for the function (Shared Key off) ----------

resource "azurerm_storage_account" "func" {
  name                     = "stragfunc${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rag.name
  location                 = azurerm_resource_group.rag.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  tags = { project = "rag-app" }
}

# Flex Consumption keeps your deployed code package here
resource "azurerm_storage_container" "func_package" {
  name                  = "app-package"
  storage_account_id    = azurerm_storage_account.func.id
  container_access_type = "private"
}

# The app identity runs the Functions host on this storage (locks, keys, the code package)
resource "azurerm_role_assignment" "app_func_storage" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------- The plan and the app ----------

resource "azurerm_service_plan" "func" {
  name                = "asp-rag-func-eus"
  resource_group_name = azurerm_resource_group.rag.name
  location            = azurerm_resource_group.rag.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption: pay per execution, scales to zero
  tags                = { project = "rag-app" }
}

resource "azapi_resource" "func" {
  type      = "Microsoft.Web/sites@2024-04-01"
  name      = "func-rag-eus-${random_string.suffix.result}"
  parent_id = azurerm_resource_group.rag.id
  location  = azurerm_resource_group.rag.location

  # Same user-assigned identity as the container apps: it already has
  # Cognitive Services OpenAI User on Foundry and Data Contributor on Cosmos.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  body = {
    kind = "functionapp,linux"
    properties = {
      serverFarmId = azurerm_service_plan.func.id
      httpsOnly    = true
      siteConfig = {
        minTlsVersion = "1.2"
        appSettings = [
          # Host storage by identity (the "__" settings replace a connection string)
          { name = "AzureWebJobsStorage__accountName", value = azurerm_storage_account.func.name },
          { name = "AzureWebJobsStorage__credential", value = "managedidentity" },
          { name = "AzureWebJobsStorage__clientId", value = azurerm_user_assigned_identity.app.client_id },
          # The Cosmos DB trigger's connection, also by identity (connection = "COSMOS" in the code)
          { name = "COSMOS__accountEndpoint", value = azurerm_cosmosdb_account.rag.endpoint },
          { name = "COSMOS__credential", value = "managedidentity" },
          { name = "COSMOS__clientId", value = azurerm_user_assigned_identity.app.client_id },
          # For the function's own code (DefaultAzureCredential picks up AZURE_CLIENT_ID)
          { name = "AZURE_CLIENT_ID", value = azurerm_user_assigned_identity.app.client_id },
          { name = "COSMOS_ENDPOINT", value = azurerm_cosmosdb_account.rag.endpoint },
          { name = "OPENAI_ENDPOINT", value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com" },
          { name = "CHAT_MODEL", value = azurerm_cognitive_deployment.chat.name },
          # Session 26: logs and traces to Application Insights, authenticated with the identity
          { name = "APPLICATIONINSIGHTS_CONNECTION_STRING", value = local.appi_connection_string },
          { name = "APPLICATIONINSIGHTS_AUTHENTICATION_STRING", value = "ClientId=${azurerm_user_assigned_identity.app.client_id};Authorization=AAD" },
        ]
      }
      functionAppConfig = {
        deployment = {
          storage = {
            type  = "blobContainer"
            value = "${azurerm_storage_account.func.primary_blob_endpoint}${azurerm_storage_container.func_package.name}"
            authentication = {
              type                           = "UserAssignedIdentity"
              userAssignedIdentityResourceId = azurerm_user_assigned_identity.app.id
            }
          }
        }
        scaleAndConcurrency = {
          maximumInstanceCount = 40  # the lowest cap Flex allows
          instanceMemoryMB     = 512 # smallest size: cheapest per second, plenty for this
        }
        runtime = {
          name    = "python"
          version = "3.12"
        }
      }
    }
  }

  tags = { project = "rag-app" }

  response_export_values = ["properties.defaultHostName"]

  depends_on = [
    azurerm_role_assignment.app_func_storage,
    azurerm_cosmosdb_sql_container.leases,
    azurerm_role_assignment.app_monitoring_publisher,
  ]
}

output "function_name" {
  value = azapi_resource.func.name
}
