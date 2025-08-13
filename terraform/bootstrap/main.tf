terraform {
  required_version = ">= 1.0.0"
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
}

provider "azurerm" {
  features {}
}

# Naming and variables
variable "environment" {
  type        = string
  description = "Environment for state backend (production/staging)"
  default     = "production"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "East US"
}

locals {
  rg_name  = "tfstate-${var.environment}-rg"
  sa_name  = lower(replace("tfstate${var.environment}", "-", ""))
  sa_name2 = substr("tf${var.environment}state${random_string.suffix.id}", 0, 24)
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  special = false
  numeric = true
}

# Resource Group for state
resource "azurerm_resource_group" "state" {
  name     = local.rg_name
  location = var.location
  tags = {
    environment = var.environment
    purpose     = "terraform-state"
  }
}

# Storage Account for state (must be globally unique)
resource "azurerm_storage_account" "state" {
  name                     = local.sa_name2
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  allow_blob_public_access = false
  tags = {
    environment = var.environment
    purpose     = "terraform-state"
  }
}

# Blob container for tfstate
resource "azurerm_storage_container" "tf" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

output "state_resource_group" {
  value = azurerm_resource_group.state.name
}

output "state_storage_account" {
  value = azurerm_storage_account.state.name
}

output "state_container" {
  value = azurerm_storage_container.tf.name
}
