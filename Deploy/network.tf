resource "azurerm_virtual_network" "primary" {
  name                = "primary-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  tags                = var.tags
}

resource "azurerm_subnet" "pe-primary" {
  name                 = "pe-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "appgw-primary" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.9.0/24"]
}

resource "azurerm_subnet" "web-primary" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.11.0/24"]
}

resource "azurerm_subnet" "jumpbox-primary" {
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_virtual_network" "secondary" {
  name                = "secondary-vnet"
  address_space       = ["10.8.0.0/16"]
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.poc.name
  tags                = var.tags
}

resource "azurerm_subnet" "pe-secondary" {
  name                 = "pe-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.8.1.0/24"]
}

resource "azurerm_subnet" "appgw-secondary" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.8.9.0/24"]
}

resource "azurerm_subnet" "web-secondary" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.8.11.0/24"]
}

resource "azurerm_virtual_network_peering" "primary-to-secondary" {
  name                      = "primary-to-secondary"
  resource_group_name       = azurerm_resource_group.poc.name
  virtual_network_name      = azurerm_virtual_network.primary.name
  remote_virtual_network_id = azurerm_virtual_network.secondary.id
}

resource "azurerm_virtual_network_peering" "secondary-to-primary" {
  name                      = "secondary-to-primary"
  resource_group_name       = azurerm_resource_group.poc.name
  virtual_network_name      = azurerm_virtual_network.secondary.name
  remote_virtual_network_id = azurerm_virtual_network.primary.id
}
