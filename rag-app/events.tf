# Session 23: Blob Storage + Event Grid feeding the Session 22 ingest queue. Behind enable_messaging.
#
#   upload a .md to the "docs" container
#     -> Event Grid system topic sees "BlobCreated"
#     -> event subscription (filter: docs container, ends with .md) sends it to the Service Bus queue
#     -> the worker from Session 22 downloads the blob, chunks it, embeds it, stores it in Cosmos
#
# No keys anywhere: Shared Key is off on the storage account, and Event Grid delivers
# with its own managed identity, not a connection string.

locals {
  # Azure Resource Manager scopes for the two containers (used for role assignments)
  docs_container_scope       = var.enable_messaging ? "${azurerm_storage_account.docs[0].id}/blobServices/default/containers/docs" : null
  deadletter_container_scope = var.enable_messaging ? "${azurerm_storage_account.docs[0].id}/blobServices/default/containers/eventgrid-deadletter" : null
}

resource "azurerm_storage_account" "docs" {
  count                    = var.enable_messaging ? 1 : 0
  name                     = "stragdocs${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rag.name
  location                 = azurerm_resource_group.rag.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS" # cheapest: 3 copies in one datacenter

  shared_access_key_enabled       = false # no account keys, no SAS: Entra ID only
  default_to_oauth_authentication = true  # the portal uses your Entra sign-in, not a key
  allow_nested_items_to_be_public = false # no anonymous blob access
  min_tls_version                 = "TLS1_2"

  tags = { project = "rag-app" }
}

# Where you drop documents
resource "azurerm_storage_container" "docs" {
  count                 = var.enable_messaging ? 1 : 0
  name                  = "docs"
  storage_account_id    = azurerm_storage_account.docs[0].id # created through Resource Manager, not a key
  container_access_type = "private"
}

# Where Event Grid parks events it couldn't deliver after all its retries
resource "azurerm_storage_container" "deadletter" {
  count                 = var.enable_messaging ? 1 : 0
  name                  = "eventgrid-deadletter"
  storage_account_id    = azurerm_storage_account.docs[0].id
  container_access_type = "private"
}

# The worker's identity reads the uploaded files (read only, docs container only)
resource "azurerm_role_assignment" "app_blob_reader" {
  count                = var.enable_messaging ? 1 : 0
  scope                = local.docs_container_scope
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
  depends_on           = [azurerm_storage_container.docs]
}

# You: upload and browse files in the portal or CLI with your Entra sign-in
resource "azurerm_role_assignment" "me_blob_contributor" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_storage_account.docs[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The system topic is Event Grid's "listener" on the storage account.
# Its system-assigned identity is what delivers events to the queue.
resource "azurerm_eventgrid_system_topic" "docs" {
  count               = var.enable_messaging ? 1 : 0
  name                = "egst-rag-docs"
  resource_group_name = azurerm_resource_group.rag.name
  location            = azurerm_storage_account.docs[0].location
  source_resource_id  = azurerm_storage_account.docs[0].id
  topic_type          = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }

  tags = { project = "rag-app" }
}

# Event Grid's identity may send to the ingest queue (that queue only)
resource "azurerm_role_assignment" "eg_sb_sender" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_servicebus_queue.ingest[0].id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_eventgrid_system_topic.docs[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# Event Grid's identity may write undeliverable events to the dead-letter container
resource "azurerm_role_assignment" "eg_deadletter_writer" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_storage_account.docs[0].id # account level: Event Grid validates the dead-letter destination at the storage account
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_eventgrid_system_topic.docs[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
  depends_on           = [azurerm_storage_container.deadletter]
}

resource "azurerm_eventgrid_system_topic_event_subscription" "docs_to_queue" {
  count               = var.enable_messaging ? 1 : 0
  name                = "docs-to-ingest"
  system_topic        = azurerm_eventgrid_system_topic.docs[0].name
  resource_group_name = azurerm_resource_group.rag.name

  # Destination: the Session 22 queue, delivered with the topic's managed identity
  service_bus_queue_endpoint_id = azurerm_servicebus_queue.ingest[0].id
  delivery_identity {
    type = "SystemAssigned"
  }

  # Only new files, only in "docs", only Markdown. Everything else is filtered out here
  # and never reaches the queue (so the worker never wakes for it).
  included_event_types = ["Microsoft.Storage.BlobCreated"]
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/docs/"
    subject_ends_with   = ".md"
    case_sensitive      = false
  }

  # If the queue can't take it: retry up to 10 times within 60 minutes...
  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 60
  }

  # ...then park the event in blob storage instead of losing it
  dead_letter_identity {
    type = "SystemAssigned"
  }
  storage_blob_dead_letter_destination {
    storage_account_id          = azurerm_storage_account.docs[0].id
    storage_blob_container_name = azurerm_storage_container.deadletter[0].name
  }

  # The roles must exist before Event Grid tries to use them
  depends_on = [azurerm_role_assignment.eg_sb_sender, azurerm_role_assignment.eg_deadletter_writer]
}

output "storage_name" {
  value = one(azurerm_storage_account.docs[*].name)
}
