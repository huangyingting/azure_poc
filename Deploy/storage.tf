resource "azurerm_storage_account" "sa" {
  name                            = "sa${random_string.poc.result}"
  resource_group_name             = azurerm_resource_group.poc.name
  location                        = var.primary_location
  account_tier                    = "Standard"
  account_replication_type        = "RAGRS"
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = true
  tags                            = var.tags
}

resource "azurerm_storage_container" "content" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "design-svg" {
  name                   = "design.svg"
  content_type           = "image/svg+xml"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.content.name
  type                   = "Block"
  source                 = "./CDN/design.svg"
}

resource "azapi_update_resource" "sa" {
  type        = "Microsoft.Storage/storageAccounts@2022-05-01"
  resource_id = azurerm_storage_account.sa.id
  body = jsonencode({
    properties = {
      publicNetworkAccess = "Disabled"
    }
  })
  depends_on = [
    azurerm_storage_blob.design-svg
  ]
}
