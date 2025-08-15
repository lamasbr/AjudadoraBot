variable "name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region where the Key Vault will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to store in the Key Vault"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "secret_expiration" {
  description = "Expiration date for secrets (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "terraform_object_id" {
  description = "Object ID of the Terraform service principal"
  type        = string
}

variable "app_service_object_id" {
  description = "Object ID of the App Service managed identity (optional)"
  type        = string
  default     = null
}
