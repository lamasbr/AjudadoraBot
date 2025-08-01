# Terraform provider configurations for free-tier optimized deployment

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }

  # Terraform state backend options
  # Choose one of the following options for state management:

  # Option 1: Terraform Cloud (Free tier: up to 5 users, remote state)
  # cloud {
  #   organization = "your-org-name"
  #   workspaces {
  #     name = "ajudadorabot-production"
  #   }
  # }

  # Option 2: Azure Storage Backend (costs ~$0.05/month for small state files)
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "terraformstatexxxxxx"  # Must be globally unique
  #   container_name       = "tfstate"
  #   key                  = "ajudadorabot-production.terraform.tfstate"
  #   
  #   # Optionally use managed identity or service principal
  #   # use_msi                 = true
  #   # subscription_id         = "your-subscription-id"
  #   # tenant_id              = "your-tenant-id"
  # }

  # Option 3: Local state (not recommended for production, but free)
  # No backend configuration = local state file
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
    
    # App Service configuration - using azurerm provider features
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