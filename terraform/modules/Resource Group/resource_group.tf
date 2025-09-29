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
variable "region" { type = string }

# ===========================================================
# locals
# ===========================================================
locals {
  name_rg = var.base != "" ? "rg-${var.base}" : null
}

# -----------------------------------------------------------
# Resource Group
# -----------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = local.name_rg
  location = var.region
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "rg_name" { value = azurerm_resource_group.rg.name }
output "rg_location" { value = azurerm_resource_group.rg.location }
