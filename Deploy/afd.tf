resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd"
  resource_group_name = azurerm_resource_group.poc.name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "afd" {
  name                     = "ep"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_rule_set" "sa" {
  name                     = "sars"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "sa" {
  name                                                      = "saog"
  cdn_frontdoor_profile_id                                  = azurerm_cdn_frontdoor_profile.afd.id
  session_affinity_enabled                                  = true
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10
  health_probe {
    interval_in_seconds = 120
    path                = "/content/design.svg"
    protocol            = "Https"
    request_type        = "HEAD"
  }
  load_balancing {
    additional_latency_in_milliseconds = 60
    sample_size                        = 5
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "sa-primary" {
  name                           = "saprimary"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.sa.id
  enabled                        = true
  certificate_name_check_enabled = true
  host_name                      = azurerm_storage_account.sa.primary_blob_host
  origin_host_header             = azurerm_storage_account.sa.primary_blob_host
  priority                       = 1
  weight                         = 500
  private_link {
    request_message        = "Request access for primary from Azure Front Door"
    target_type            = "blob"
    location               = var.primary_location
    private_link_target_id = azurerm_storage_account.sa.id
  }
}

resource "azurerm_cdn_frontdoor_origin" "sa-secondary" {
  name                           = "sasecondary"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.sa.id
  enabled                        = true
  certificate_name_check_enabled = true
  host_name                      = azurerm_storage_account.sa.secondary_blob_host
  origin_host_header             = azurerm_storage_account.sa.secondary_blob_host
  priority                       = 2
  weight                         = 500
  private_link {
    request_message        = "Request access for secondary from Azure Front Door"
    target_type            = "blob_secondary"
    location               = var.primary_location
    private_link_target_id = azurerm_storage_account.sa.id
  }
}

resource "azurerm_cdn_frontdoor_rule_set" "web" {
  name                     = "webrs"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                                                      = "webog"
  cdn_frontdoor_profile_id                                  = azurerm_cdn_frontdoor_profile.afd.id
  session_affinity_enabled                                  = true
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10
  health_probe {
    interval_in_seconds = 120
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }
  load_balancing {
    additional_latency_in_milliseconds = 60
    sample_size                        = 5
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "web-primary" {
  name                           = "webprimary"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  certificate_name_check_enabled = false
  http_port                      = 80
  host_name                      = azurerm_public_ip.web-primary.ip_address
  origin_host_header             = azurerm_public_ip.web-primary.ip_address
  priority                       = 1
  weight                         = 500
}

resource "azurerm_cdn_frontdoor_origin" "web-secondary" {
  name                           = "websecondary"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                        = true
  certificate_name_check_enabled = false
  http_port                      = 80
  host_name                      = azurerm_public_ip.web-secondary.ip_address
  origin_host_header             = azurerm_public_ip.web-secondary.ip_address
  priority                       = 2
  weight                         = 500
}

data "azurerm_dns_zone" "dns_zone" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_cdn_frontdoor_custom_domain" "afd" {
  name                     = "cd"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  dns_zone_id              = data.azurerm_dns_zone.dns_zone.id
  host_name                = "afd.${var.dns_zone_name}"
  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_dns_txt_record" "afd" {
  name                = join(".", ["_dnsauth", "afd"])
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 3600
  record {
    value = azurerm_cdn_frontdoor_custom_domain.afd.validation_token
  }
}

resource "azurerm_cdn_frontdoor_route" "sa" {
  name                            = "saroute"
  cdn_frontdoor_origin_path       = "/content"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.afd.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.sa.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.sa-primary.id, azurerm_cdn_frontdoor_origin.sa-secondary.id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.sa.id]
  enabled                         = true
  forwarding_protocol             = "MatchRequest"
  https_redirect_enabled          = true
  patterns_to_match               = ["/content/*"]
  supported_protocols             = ["Http", "Https"]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.afd.id]
  link_to_default_domain          = true
  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/javascript", "text/xml"]
  }
}

resource "azurerm_cdn_frontdoor_route" "web" {
  name                            = "webroute"
  cdn_frontdoor_origin_path       = "/"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.afd.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.web-primary.id, azurerm_cdn_frontdoor_origin.web-secondary.id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.web.id]
  enabled                         = true
  forwarding_protocol             = "HttpOnly"
  https_redirect_enabled          = true
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.afd.id]
  link_to_default_domain          = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "afd" {
  name                = "frontdoorwaf"
  resource_group_name = azurerm_resource_group.poc.name
  sku_name            = azurerm_cdn_frontdoor_profile.afd.sku_name
  enabled             = true
  mode                = "Prevention"
  redirect_url        = "https://www.microsoft.com"
  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.0"
    action  = "Block"
  }
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Log"
  }
  tags = var.tags
}

resource "azurerm_cdn_frontdoor_security_policy" "afd" {
  name                     = "sp"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.afd.id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.afd.id
        }
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.afd.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
