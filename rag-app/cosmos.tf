# Session 16: Cosmos DB for NoSQL (free tier) for the vectors. Keys off, Entra ID only.

resource "azurerm_cosmosdb_account" "rag" {
  name                = "cosmos-rag-eus-${random_string.suffix.result}"
  location            = azurerm_resource_group.rag.location
  resource_group_name = azurerm_resource_group.rag.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB" # = Cosmos DB for NoSQL

  free_tier_enabled            = true  # first 1000 RU/s and 25 GB free. One per subscription.
  local_authentication_enabled = false # no account keys

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rag.location
    failover_priority = 0
  }

  tags = { project = "rag-app" }
}

# Database with NO shared throughput: vector search needs throughput set on the container instead
resource "azurerm_cosmosdb_sql_database" "rag" {
  name                = "ragdb"
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
}

# Let YOU read and write items with your Entra ID sign-in.
# Built-in role 00000000-0000-0000-0000-000000000002 = Cosmos DB Built-in Data Contributor
resource "azurerm_cosmosdb_sql_role_assignment" "me_data_contributor" {
  resource_group_name = azurerm_resource_group.rag.name
  account_name        = azurerm_cosmosdb_account.rag.name
  role_definition_id  = "${azurerm_cosmosdb_account.rag.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = data.azurerm_client_config.current.object_id
  scope               = azurerm_cosmosdb_account.rag.id
}

# The "chunks" container is made with the Azure CLI in the session steps, because the
# azurerm provider can't set a vector policy yet. Destroying ragdb deletes it too.

output "cosmos_name" {
  value = azurerm_cosmosdb_account.rag.name
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.rag.endpoint
}