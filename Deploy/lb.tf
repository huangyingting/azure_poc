resource "azurerm_public_ip" "crlb" {
  name                = "crlb"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  sku_tier            = "Global"
  allocation_method   = "Static"
  domain_name_label   = "crlb${random_string.poc.result}"
  tags                = var.tags
}

resource "azurerm_lb" "crlb" {
  name                = "crlb"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  sku_tier            = "Global"
  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.crlb.id
  }
}

resource "azurerm_lb_backend_address_pool" "crlb" {
  loadbalancer_id = azurerm_lb.crlb.id
  name            = "backend"
}

resource "azurerm_lb_backend_address_pool_address" "primary" {
  name                                = "primary"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.crlb.id
  backend_address_ip_configuration_id = azurerm_lb.web-primary.frontend_ip_configuration[0].id
}

resource "azurerm_lb_backend_address_pool_address" "secondary" {
  name                                = "secondary"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.crlb.id
  backend_address_ip_configuration_id = azurerm_lb.web-secondary.frontend_ip_configuration[0].id
}

resource "azurerm_lb_rule" "poc" {
  loadbalancer_id                = azurerm_lb.crlb.id
  name                           = "web-http"
  protocol                       = "Tcp"
  frontend_port                  = var.http_port
  backend_port                   = var.http_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.crlb.id]
  frontend_ip_configuration_name = "frontend"
}
