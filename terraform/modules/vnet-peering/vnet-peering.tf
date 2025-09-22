# ===========================================================
# 変数定義
# ===========================================================

# -----------------------------------------------------------
# Spokeサブスクリプション／テナント
# -----------------------------------------------------------
variable "effective_spoke_subscription_id" {
  description = "新規作成時は azapi の data/resource から取得、既存流用時はそのまま"
  type        = string
}

# -----------------------------------------------------------
# Hub情報（Peering用）
# -----------------------------------------------------------
variable "hub_subscription_id" {
  description = "Hub Subscription ID"
  type        = string
}
variable "hub_vnet_name" {
  description = "Hub側のVNet名"
  type        = string
}
variable "hub_rg_name" {
  description = "Hub側のリソースグループ名"
  type        = string
}


variable "base" {
  type        = string
}

variable "project_slug" {
  description = "プロジェクト名のスラッグ（命名用）"
  type        = string
}

variable "environment_id" {
  description = "環境識別子（prd/stg/dev 等）"
  type        = string
}

variable "sequence" {
  description = "通番（例: 001）"
  type        = string
}

# ===========================================================
# providers
# ===========================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
      configuration_aliases = [ azurerm.spoke, azurerm.hub ]
    }
  }
}

# ===========================================================
# locals
# ===========================================================
locals {
  name_rg                  = var.base != "" ? "rg-${var.base}" : null
  name_vnet                = var.base != "" ? "vnet-${var.base}" : null
  name_vnetpeer_hub2spoke  = var.project_slug != "" ? "peer-${var.project_slug}-hubtospoke-${var.environment_id}-${var.sequence}" : null
  name_vnetpeer_spoke2hub  = var.project_slug != "" ? "peer-${var.project_slug}-spoketohub-${var.environment_id}-${var.sequence}" : null
}

# -----------------------------------------------------------
# VNet Peering（Hub⇔Spoke）
# -----------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = local.name_vnetpeer_hub2spoke
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${var.effective_spoke_subscription_id}/resourceGroups/${local.name_rg}/providers/Microsoft.Network/virtualNetworks/${local.name_vnet}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.spoke
  name                      = local.name_vnetpeer_spoke2hub
  resource_group_name       = local.name_rg
  virtual_network_name      = local.name_vnet
  remote_virtual_network_id = "/subscriptions/${var.hub_subscription_id}/resourceGroups/${var.hub_rg_name}/providers/Microsoft.Network/virtualNetworks/${var.hub_vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true

  depends_on = [
    azurerm_virtual_network_peering.hub_to_spoke
  ]
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "hub_to_spoke_peering_id"   { value = azurerm_virtual_network_peering.hub_to_spoke.id }
output "spoke_to_hub_peering_id"   { value = azurerm_virtual_network_peering.spoke_to_hub.id }

