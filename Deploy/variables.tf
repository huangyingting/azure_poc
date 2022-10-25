variable "primary_location" {
  default = "eastasia"
}

variable "secondary_location" {
  default = "southeastasia"
}

variable "resource_group_name" {
  default = "POC"
}

variable "email_address" {
  type    = string
  default = ""
}

variable "certificate_name" {
  type    = string
  default = ""
}

variable "dns_zone_name" {
  type    = string
  default = ""
}

variable "dns_zone_resource_group_name" {
  type    = string
  default = ""
}

variable "azure_client_id" {
  type    = string
  default = ""
}

variable "azure_client_secret" {
  type    = string
  default = ""
}

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_tenant_id" {
  type    = string
  default = ""
}

variable "tags" {
  default = {
    environment = "poc"
  }
}

variable "http_port" {
  default = 80
}

variable "vm_size" {
  type    = string
  default = "Standard_F1s"
}

variable "admin_username" {
  type    = string
  default = ""
}

variable "sql_admin_username" {
  type    = string
  default = ""
}

variable "sql_admin_password" {
  type    = string
  default = ""
}
