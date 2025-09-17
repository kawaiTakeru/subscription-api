terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
    }
  }
}

variable "spoke_subscription_id" { type = string }
variable "spoke_tenant_id" { type = string }
variable "name_rg" { type = string }
variable "region" { type = string }

resource "azurerm_resource_group" "rg" {
  name     = var.name_rg
  location = var.region
}

output "rg_name" { value = azurerm_resource_group.rg.name }
output "rg_location" { value = azurerm_resource_group.rg.location }
