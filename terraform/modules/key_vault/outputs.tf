output "id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

output "terraform_access_policy_id" {
  description = "ID of the Terraform access policy"
  value       = azurerm_key_vault_access_policy.terraform.id
}

output "app_service_access_policy_id" {
  description = "ID of the App Service access policy (if created)"
  value       = var.app_service_object_id != null ? azurerm_key_vault_access_policy.app_service[0].id : null
}
