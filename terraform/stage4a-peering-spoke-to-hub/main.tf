terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

# Spoke 側（デフォルト）: CLI の現在サブスクリプションを使用
provider "azurerm" {
  features {}
}

# Hub 側: 明示的に別サブスクリプションを指定
provider "azurerm" {
  alias           = "hub"
  features        = {}
  subscription_id = var.hub_subscription_id
}

# 既存 VNet を参照
data "azurerm_virtual_network" "spoke" {
  name                = var.spoke_vnet_name
  resource_group_name = var.spoke_rg_name
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = var.hub_vnet_name
  resource_group_name = var.hub_rg_name
}

# Spoke -> Hub ピアリング
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = data.azurerm_virtual_network.spoke.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.spoke.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true
}

