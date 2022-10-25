resource "azurerm_mssql_server" "primary" {
  name                         = "sqlprimary${random_string.poc.result}"
  resource_group_name          = azurerm_resource_group.poc.name
  location                     = var.primary_location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags
}

resource "azurerm_mssql_server" "secondary" {
  name                         = "sqlsecondary${random_string.poc.result}"
  resource_group_name          = azurerm_resource_group.poc.name
  location                     = var.secondary_location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags
}

resource "azurerm_mssql_database" "db" {
  name         = "db"
  server_id    = azurerm_mssql_server.primary.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "Basic"
  tags         = var.tags
}

resource "azurerm_mssql_failover_group" "failover" {
  name      = "sqlfg${random_string.poc.result}"
  server_id = azurerm_mssql_server.primary.id
  databases = [
    azurerm_mssql_database.db.id
  ]
  partner_server {
    id = azurerm_mssql_server.secondary.id
  }
  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }
  tags = var.tags
}


resource "azurerm_private_dns_zone" "database" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.poc.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "database-primary" {
  name                  = "database-primary-link"
  resource_group_name   = azurerm_resource_group.poc.name
  private_dns_zone_name = azurerm_private_dns_zone.database.name
  virtual_network_id    = azurerm_virtual_network.primary.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "database-secondary" {
  name                  = "database-secondary-link"
  resource_group_name   = azurerm_resource_group.poc.name
  private_dns_zone_name = azurerm_private_dns_zone.database.name
  virtual_network_id    = azurerm_virtual_network.secondary.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "primary" {
  name                = "sqlprimary${random_string.poc.result}-pe"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  subnet_id           = azurerm_subnet.pe-primary.id

  private_service_connection {
    name                           = "sqlprimary${random_string.poc.result}-pe"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.primary.id
    subresource_names              = ["sqlServer"]
  }
  private_dns_zone_group {
    name                 = "sqlprimary${random_string.poc.result}"
    private_dns_zone_ids = [azurerm_private_dns_zone.database.id]
  }
  depends_on = [
    azurerm_virtual_network_peering.primary-to-secondary,
    azurerm_virtual_network_peering.secondary-to-primary
  ]  
  tags = var.tags
}

resource "azurerm_private_endpoint" "secondary" {
  name                = "sqlsecondary${random_string.poc.result}-pe"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.secondary_location
  subnet_id           = azurerm_subnet.pe-secondary.id
  private_service_connection {
    name                           = "sqlsecondary${random_string.poc.result}-pe"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.secondary.id
    subresource_names              = ["sqlServer"]
  }
  private_dns_zone_group {
    name                 = "sqlsecondary${random_string.poc.result}"
    private_dns_zone_ids = [azurerm_private_dns_zone.database.id]
  }
  depends_on = [
    azurerm_virtual_network_peering.primary-to-secondary,
    azurerm_virtual_network_peering.secondary-to-primary
  ]  
  tags = var.tags
}
