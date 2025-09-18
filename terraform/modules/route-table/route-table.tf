# ===========================================================
# 変数定義
# ===========================================================

# -----------------------------------------------------------
# サブスクリプション・命名規約関連（Stage0相当）
# -----------------------------------------------------------
variable "environment_id" {
  description = "環境識別子（例: prd, stg, dev）"
  type        = string
  default     = "prd"
}

variable "region_code" {
  description = "リージョン略号（例: jpe=japaneast）"
  type        = string
  default     = "jpe"
}

variable "sequence" {
  description = "リソース名の通番（ゼロ埋め文字列推奨: 001）"
  type        = string
  default     = "001"
}

# -----------------------------------------------------------
variable "project_slug" {
  type        = string
}

variable "base" {
  type        = string
}

variable "resource_group_location" {
  type        = string
}

variable "resource_group_name" {
  type        = string
}

variable "subnet_id" {
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
      configuration_aliases = [ azurerm ]
    }
  }
}

# ===========================================================
# locals
# ===========================================================
locals {
  name_route_table         = var.base != "" ? "rt-${var.base}" : null
  name_udr_default         = var.project_slug != "" ? "udr-${var.project_slug}-er-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms1            = var.project_slug != "" ? "udr-${var.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms2            = var.project_slug != "" ? "udr-${var.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-002" : null
  name_udr_kms3            = var.project_slug != "" ? "udr-${var.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-003" : null
}

# -----------------------------------------------------------
# ルートテーブル・ルート（プライベート環境のみ）
# -----------------------------------------------------------
resource "azurerm_route_table" "route_table_private" {
  provider            = azurerm
  name                = local.name_route_table
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

resource "azurerm_route" "route_default_to_gateway" {
  provider            = azurerm
  name                = local.name_udr_default
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_private.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_route" "route_kms1" {
  provider            = azurerm
  name                = local.name_udr_kms1
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_private.name
  address_prefix      = "20.118.99.224/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms2" {
  provider            = azurerm
  name                = local.name_udr_kms2
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_private.name
  address_prefix      = "40.83.235.53/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms3" {
  provider            = azurerm
  name                = local.name_udr_kms3
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.route_table_private.name
  address_prefix      = "23.102.135.246/32"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "subnet_rt_assoc" {
  provider       = azurerm
  subnet_id      = var.subnet_id
  route_table_id = azurerm_route_table.route_table_private.id
}
