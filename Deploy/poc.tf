resource "azurerm_resource_group" "poc" {
  name     = var.resource_group_name
  location = var.primary_location
  tags     = var.tags
}

resource "random_string" "poc" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

