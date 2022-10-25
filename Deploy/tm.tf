resource "azurerm_traffic_manager_profile" "tm" {
  name                   = "tm"
  resource_group_name    = azurerm_resource_group.poc.name
  traffic_routing_method = "Priority"
  dns_config {
    relative_name = "tm-${random_string.poc.result}"
    ttl           = 100
  }
  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
  tags = var.tags
}

resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  name               = "tm-primary"
  profile_id         = azurerm_traffic_manager_profile.tm.id
  target_resource_id = azurerm_public_ip.web-primary.id
  priority           = 1
}

resource "azurerm_traffic_manager_azure_endpoint" "secondary" {
  name               = "tm-secondary"
  profile_id         = azurerm_traffic_manager_profile.tm.id
  target_resource_id = azurerm_public_ip.web-secondary.id
  priority           = 2
}
