terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# hub サブスクリプションで実行
provider "azurerm" {
  features {}
}

# Spoke 側 VNet のリソースIDを組み立て
locals {
  spoke_vnet_id = "/subscriptions/${var.spoke_subscription_id}/resourceGroups/${var.spoke_rg_name}/providers/Microsoft.Network/virtualNetworks/${var.spoke_vnet_name}"
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = local.spoke_vnet_id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}
