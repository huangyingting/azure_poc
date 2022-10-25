resource "tls_private_key" "ssl" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_registration" "ssl" {
  account_key_pem = tls_private_key.ssl.private_key_pem
  email_address   = var.email_address
}

resource "acme_certificate" "ssl" {
  account_key_pem           = acme_registration.ssl.account_key_pem
  common_name               = var.dns_zone_name
  subject_alternative_names = [var.dns_zone_name]
  dns_challenge {
    provider = "azure"
    config = {
      AZURE_CLIENT_ID       = var.azure_client_id
      AZURE_CLIENT_SECRET   = var.azure_client_secret
      AZURE_RESOURCE_GROUP  = var.dns_zone_resource_group_name
      AZURE_SUBSCRIPTION_ID = var.azure_subscription_id
      AZURE_TENANT_ID       = var.azure_tenant_id
      AZURE_ZONE_NAME       = var.dns_zone_name
    }
  }
}
