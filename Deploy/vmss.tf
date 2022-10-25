# primary
resource "azurerm_public_ip" "web-primary" {
  name                = "webprimary"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "webprimary${random_string.poc.result}"
  tags                = var.tags
}

resource "azurerm_lb" "web-primary" {
  name                = "webprimary"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.web-primary.id
  }
  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "web-primary" {
  loadbalancer_id = azurerm_lb.web-primary.id
  name            = "backend"
}

resource "azurerm_lb_probe" "web-primary" {
  loadbalancer_id = azurerm_lb.web-primary.id
  name            = "probe"
  port            = var.http_port
}

resource "azurerm_lb_rule" "web-primary" {
  loadbalancer_id                = azurerm_lb.web-primary.id
  name                           = "web-http"
  protocol                       = "Tcp"
  frontend_port                  = var.http_port
  backend_port                   = var.http_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web-primary.id]
  frontend_ip_configuration_name = "frontend"
  probe_id                       = azurerm_lb_probe.web-primary.id
}

resource "azurerm_linux_virtual_machine_scale_set" "web-primary" {
  name                = "webprimary"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  sku                 = var.vm_size
  instances           = 1
  admin_username      = var.admin_username
  custom_data         = base64encode(replace(file("vmss.yaml"), "REPLACE_ME", "Server=tcp:${azurerm_mssql_failover_group.failover.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.primary.administrator_login};Password=${azurerm_mssql_server.primary.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"))
  priority            = "Spot"
  eviction_policy     = "Deallocate"
  upgrade_mode        = "Rolling"
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "web-nic"
    primary = true

    ip_configuration {
      name                                         = "ip-config"
      primary                                      = true
      subnet_id                                    = azurerm_subnet.web-primary.id
      load_balancer_backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web-primary.id]
      application_gateway_backend_address_pool_ids = ["${azurerm_application_gateway.primary.id}/backendAddressPools/web"]
    }
  }
  health_probe_id = azurerm_lb_probe.web-primary.id
  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 50
    pause_time_between_batches              = "PT0S"
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT60M"
  }
  tags       = var.tags
  depends_on = [azurerm_lb_rule.web-primary, azurerm_mssql_failover_group.failover]
}

resource "azurerm_network_security_group" "web-primary" {
  name                = "webprimary-nsg"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web-primary" {
  subnet_id                 = azurerm_subnet.web-primary.id
  network_security_group_id = azurerm_network_security_group.web-primary.id
  depends_on = [
    azurerm_linux_virtual_machine_scale_set.web-primary
  ]
}

resource "azurerm_monitor_autoscale_setting" "web-primary" {
  name                = "webprimary-autoscale"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web-primary.id
  profile {
    name = "web-profile"
    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web-primary.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 50
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web-primary.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
    }
  }
}

# secondary
resource "azurerm_public_ip" "web-secondary" {
  name                = "websecondary"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "websecondary${random_string.poc.result}"
  tags                = var.tags
}

resource "azurerm_lb" "web-secondary" {
  name                = "websecondary"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.web-secondary.id
  }
  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "web-secondary" {
  loadbalancer_id = azurerm_lb.web-secondary.id
  name            = "backend"
}

resource "azurerm_lb_probe" "web-secondary" {
  loadbalancer_id = azurerm_lb.web-secondary.id
  name            = "probe"
  port            = var.http_port
}

resource "azurerm_lb_rule" "web-secondary" {
  loadbalancer_id                = azurerm_lb.web-secondary.id
  name                           = "web-http"
  protocol                       = "Tcp"
  frontend_port                  = var.http_port
  backend_port                   = var.http_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web-secondary.id]
  frontend_ip_configuration_name = "frontend"
  probe_id                       = azurerm_lb_probe.web-secondary.id
}

resource "azurerm_linux_virtual_machine_scale_set" "web-secondary" {
  name                = "websecondary"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.secondary_location
  sku                 = var.vm_size
  instances           = 1
  admin_username      = var.admin_username
  custom_data         = base64encode(replace(file("vmss.yaml"), "REPLACE_ME", "Server=tcp:${azurerm_mssql_failover_group.failover.name}.secondary.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.secondary.administrator_login};Password=${azurerm_mssql_server.secondary.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"))
  priority            = "Spot"
  eviction_policy     = "Deallocate"
  upgrade_mode        = "Rolling"
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "web-nic"
    primary = true

    ip_configuration {
      name                                   = "ip-config"
      primary                                = true
      subnet_id                              = azurerm_subnet.web-secondary.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web-secondary.id]
    }
  }
  health_probe_id = azurerm_lb_probe.web-secondary.id
  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 50
    pause_time_between_batches              = "PT0S"
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT60M"
  }
  tags       = var.tags
  depends_on = [azurerm_lb_rule.web-secondary, azurerm_mssql_failover_group.failover]
}

resource "azurerm_network_security_group" "web-secondary" {
  name                = "websecondary-nsg"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.poc.name
  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web-secondary" {
  subnet_id                 = azurerm_subnet.web-secondary.id
  network_security_group_id = azurerm_network_security_group.web-secondary.id
  depends_on = [
    azurerm_linux_virtual_machine_scale_set.web-secondary
  ]
}

resource "azurerm_monitor_autoscale_setting" "web-secondary" {
  name                = "websecondary-autoscale"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.secondary_location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web-secondary.id
  profile {
    name = "web-profile"
    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web-secondary.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 50
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web-secondary.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
    }
  }
}
