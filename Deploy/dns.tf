resource "azurerm_dns_a_record" "appgw-primary" {
  name                = "appgwprimary"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.appgw-primary.id
}

resource "azurerm_dns_a_record" "web-primary" {
  name                = "webprimary"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.web-primary.id
}

resource "azurerm_dns_a_record" "web-secondary" {
  name                = "websecondary"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.web-secondary.id
}

resource "azurerm_dns_a_record" "lb" {
  name                = "crlb"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.crlb.id
}


resource "azurerm_dns_cname_record" "tm" {
  name                = "tm"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  record              = azurerm_traffic_manager_profile.tm.fqdn
}

resource "azurerm_dns_cname_record" "afd" {
  name                = "afd"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 600
  record              = azurerm_cdn_frontdoor_endpoint.afd.host_name
}
