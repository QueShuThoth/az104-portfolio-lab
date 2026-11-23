# Session 22: Service Bus Standard + the "ingest" queue + the worker app. Behind enable_messaging.
# Standard (not Basic) because Basic has no topics. Keys off: Entra ID only.
# Private endpoints would need Premium, so Service Bus stays on its public endpoint (Phase 2 decision).

variable "worker_image_tag" {
  description = "Image tag the ingest worker runs"
  type        = string
  default     = "v1"
}

resource "azurerm_servicebus_namespace" "rag" {
  count               = var.enable_messaging ? 1 : 0
  name                = "sb-rag-eus-${random_string.suffix.result}"
  location            = azurerm_resource_group.rag.location
  resource_group_name = azurerm_resource_group.rag.name
  sku                 = "Standard"
  local_auth_enabled  = false # no connection strings or SAS keys
  minimum_tls_version = "1.2"
  tags                = { project = "rag-app" }
}

resource "azurerm_servicebus_queue" "ingest" {
  count        = var.enable_messaging ? 1 : 0
  name         = "ingest"
  namespace_id = azurerm_servicebus_namespace.rag[0].id

  max_delivery_count                   = 5 # 5 failed tries, then the dead-letter queue
  lock_duration                        = "PT1M"
  default_message_ttl                  = "P1D" # messages older than a day expire...
  dead_lettering_on_message_expiration = true  # ...into the dead-letter queue, not the bin
}

# You: send test messages from the laptop
resource "azurerm_role_assignment" "me_sb_sender" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_servicebus_queue.ingest[0].id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = data.azurerm_client_config.current.object_id
}

# You: peek at the dead-letter queue in Service Bus Explorer
resource "azurerm_role_assignment" "me_sb_receiver" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_servicebus_queue.ingest[0].id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The app identity: receive messages, and let the KEDA scale rule read the queue length.
# Reading message counts needs the "Manage" right, which only Data Owner has,
# so it's scoped to this one queue rather than the whole namespace.
resource "azurerm_role_assignment" "app_sb_owner" {
  count                = var.enable_messaging ? 1 : 0
  scope                = azurerm_servicebus_queue.ingest[0].id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "worker" {
  count                        = var.enable_messaging && var.enable_registry ? 1 : 0
  name                         = "ca-rag-worker"
  container_app_environment_id = azurerm_container_app_environment.rag.id
  resource_group_name          = azurerm_resource_group.rag.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = azurerm_container_registry.rag[0].login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  # No ingress block: nothing can call the worker. It only pulls from the queue.

  template {
    min_replicas = 0
    max_replicas = 3

    # KEDA: one replica per 5 waiting messages, checked every 30 seconds, using the managed identity
    custom_scale_rule {
      name             = "ingest-queue"
      custom_rule_type = "azure-servicebus"
      metadata = {
        namespace    = azurerm_servicebus_namespace.rag[0].name
        queueName    = azurerm_servicebus_queue.ingest[0].name
        messageCount = "5"
      }
      identity_id = azurerm_user_assigned_identity.app.id
    }

    container {
      name   = "worker"
      image  = "${azurerm_container_registry.rag[0].login_server}/rag-worker:${var.worker_image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "SERVICEBUS_NAMESPACE_FQDN"
        value = "${azurerm_servicebus_namespace.rag[0].name}.servicebus.windows.net"
      }
      env {
        name  = "OPENAI_ENDPOINT"
        value = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com"
      }
      env {
        name  = "COSMOS_ENDPOINT"
        value = azurerm_cosmosdb_account.rag.endpoint
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.app.client_id
      }
      env {
        # Demo throttle so you can watch it scale out. Set to 0 for real use.
        name  = "WORK_DELAY_SECONDS"
        value = "3"
      }
    }
  }

  tags = { project = "rag-app" }

  depends_on = [azurerm_role_assignment.app_acr_pull, azurerm_role_assignment.app_sb_owner]
}

output "servicebus_name" {
  value = one(azurerm_servicebus_namespace.rag[*].name)
}
