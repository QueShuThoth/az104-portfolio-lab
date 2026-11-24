terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Session 24: azapi talks straight to the Azure Resource Manager API.
    # Used for the Flex Consumption function app only (see functions.tf for why).
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
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
    # Session 23: the storage accounts have Shared Key turned off. Without this, Terraform
    # tries to read queue and static-website settings with a key and gets "403 not permitted".
    # With it off, Terraform manages the accounts and their containers only through
    # Azure Resource Manager, which uses your Entra sign-in.
    storage {
      data_plane_available = false
    }
    # Session 26: Azure normally adds a "Failure Anomalies" alert rule (and sometimes an
    # action group) next to a new Application Insights. Terraform doesn't track those, so they
    # could block end-of-day destroy. This tells Terraform to switch that extra rule off.
    application_insights {
      disable_generated_rule = true
    }
  }
}

# azapi also reads $env:ARM_SUBSCRIPTION_ID and your az login. Nothing to put here.
provider "azapi" {}
