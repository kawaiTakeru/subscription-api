terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # ★ ここを v4 系に更新
      version = "~> 4.41"
    }
  }
}

provider "azurerm" {
  features {}
  # ★ 追加：ここで明示
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # ★ address_space は使わず、IPAM のプールから自動割当
  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}
