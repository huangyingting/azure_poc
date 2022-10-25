# primary
resource "azurerm_public_ip" "appgw-primary" {
  name                = "appgwprimary"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "appgwprimary${random_string.poc.result}"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "primary" {
  name                = "appgwwaf"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
    }
  }
  tags = var.tags
}

resource "azurerm_application_gateway" "primary" {
  name                = "appgwprimary"
  resource_group_name = azurerm_resource_group.poc.name
  location            = var.primary_location
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }
  gateway_ip_configuration {
    name      = "gwip-config"
    subnet_id = azurerm_subnet.appgw-primary.id
  }
  frontend_port {
    name = "fe-http"
    port = 80
  }
  frontend_port {
    name = "fe-https"
    port = 443
  }
  ssl_certificate {
    name     = var.certificate_name
    data     = acme_certificate.ssl.certificate_p12
    password = ""
  }
  frontend_ip_configuration {
    name                 = "feip-config"
    public_ip_address_id = azurerm_public_ip.appgw-primary.id
  }
  backend_address_pool {
    name = "web"
  }
  backend_http_settings {
    name                  = "web-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }
  http_listener {
    name                           = "web-http-listener"
    frontend_ip_configuration_name = "feip-config"
    frontend_port_name             = "fe-http"
    protocol                       = "Http"
  }
  http_listener {
    name                           = "web-https-listener"
    frontend_ip_configuration_name = "feip-config"
    frontend_port_name             = "fe-https"
    protocol                       = "Https"
    ssl_certificate_name           = var.certificate_name
  }
  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "web-https-listener"
    include_path         = true
    include_query_string = true
  }
  request_routing_rule {
    name                        = "web-http"
    priority                    = 100
    rule_type                   = "Basic"
    http_listener_name          = "web-http-listener"
    redirect_configuration_name = "http-to-https"
  }
  request_routing_rule {
    name                       = "web-https"
    priority                   = 200
    rule_type                  = "Basic"
    http_listener_name         = "web-https-listener"
    backend_address_pool_name  = "web"
    backend_http_settings_name = "web-http"
  }
  firewall_policy_id = azurerm_web_application_firewall_policy.primary.id
  tags               = var.tags
}
