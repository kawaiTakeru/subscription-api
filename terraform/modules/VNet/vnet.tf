# ===========================================================
# providers
# ===========================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
    }
  }
}

# ===========================================================
# 変数定義
# ===========================================================

variable "spoke_subscription_id" { type = string }
variable "spoke_tenant_id" { type = string }
variable "base" { type = string }
variable "rg_name" { type = string }
variable "region" { type = string }
variable "ipam_pool_id" { type = string }
variable "vnet_number_of_ips" { type = number }

# ===========================================================
# locals
# ===========================================================
locals {
  name_vnet = var.base != "" ? "vnet-${var.base}" : null
}

# -----------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = local.name_vnet
  location            = var.region
  resource_group_name = var.rg_name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "vnet_name" { value = azurerm_virtual_network.vnet.name }


