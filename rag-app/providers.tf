terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Subscription comes from $env:ARM_SUBSCRIPTION_ID, never from this file (public repo)
provider "azurerm" {
  features {
    # Foundry resources are soft-deleted on destroy. Purge them so nothing lingers.
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    # Log Analytics workspaces are also soft-deleted for 14 days unless this is on.
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}
