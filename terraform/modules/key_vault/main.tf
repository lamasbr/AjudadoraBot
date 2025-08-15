resource "azurerm_key_vault" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tenant_id                       = var.tenant_id
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = false
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false
  sku_name                        = "standard"
  public_network_access_enabled   = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id       = azurerm_key_vault.this.id
  tenant_id          = var.tenant_id
  object_id          = var.terraform_object_id
  secret_permissions = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
}

resource "azurerm_key_vault_access_policy" "app_service" {
  count              = var.app_service_object_id != null ? 1 : 0
  key_vault_id       = azurerm_key_vault.this.id
  tenant_id          = var.tenant_id
  object_id          = var.app_service_object_id
  secret_permissions = ["Get", "List"]
}

locals {
  expiration = var.secret_expiration == null || var.secret_expiration == "" ? null : var.secret_expiration
}

resource "azurerm_key_vault_secret" "this" {
  for_each        = var.secrets
  name            = each.key
  value           = each.value
  key_vault_id    = azurerm_key_vault.this.id
  content_type    = "Managed by Terraform"
  expiration_date = local.expiration
  tags            = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.terraform,
    azurerm_key_vault_access_policy.app_service
  ]
}

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
