terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

# Spoke 側（デフォルト）
provider "azurerm" {
  features {}
}

# Hub 側（エイリアス）
provider "azurerm" {
  alias           = "hub"
  features        = {}
  subscription_id = var.hub_subscription_id
}

# Spoke VNet は default provider 側で参照
data "azurerm_virtual_network" "spoke" {
  name                = var.spoke_vnet_name
  resource_group_name = var.spoke_rg_name
}

# Hub -> Spoke ピアリング（Hub サブスクリプション側で作成）
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "hub-to-spoke"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.spoke.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}

