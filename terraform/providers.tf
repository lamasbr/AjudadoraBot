# Terraform provider configurations for free-tier optimized deployment

terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Remote state backend (recomendado). Não é possível parametrizar via variáveis aqui.
  # Descomente e preencha para usar Azure Storage como backend remoto:
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "terraformstatexxxxxx"  # único globalmente
  #   container_name       = "tfstate"
  #   key                  = "ajudadorabot-${var.environment}.tfstate" # NÃO SUPORTA variáveis - ajuste manualmente
  # }

  # Alternativa Terraform Cloud:
  # cloud {
  #   organization = "your-org-name"
  #   workspaces { name = "ajudadorabot-${var.environment}" }
  # }
}

# Azure Resource Manager Provider
provider "azurerm" {
  features {
    # Key Vault configuration for free tier optimization
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    # Resource Group configuration
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # Optional: Specify subscription if you have multiple
  # subscription_id = "your-subscription-id"
  # tenant_id      = "your-tenant-id"

  # Skip provider registration for faster deployments (if providers already registered)
  skip_provider_registration = false
}

# Random provider for generating secrets
provider "random" {
  # No configuration required
}