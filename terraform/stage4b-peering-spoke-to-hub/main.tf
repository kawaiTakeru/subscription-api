terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

# このステージは Spoke サブスクリプションで実行
provider "azurerm" { features {} }

locals {
  hub_vnet_id = "/subscriptions/${var.hub_subscription_id}/resourceGroups/${var.hub_rg_name}/providers/Microsoft.Network/virtualNetworks/${var.hub_vnet_name}"
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = var.spoke_rg_name
  virtual_network_name      = var.spoke_vnet_name
  remote_virtual_network_id = local.hub_vnet_id

  allow_gateway_transit        = false
  use_remote_gateways          = true   # Hub 側 transit 有効化後に借用
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
