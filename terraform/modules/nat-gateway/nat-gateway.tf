# ===========================================================
# 変数定義
# ===========================================================

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

variable "project_slug"             { type = string }
variable "resource_group_location"  { type = string }
variable "resource_group_name"      { type = string }
variable "subnet_id"                { type = string }

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
  name_natgw     = var.project_slug != "" ? "ng-${var.project_slug}-nat-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_natgw_pip = var.project_slug != "" ? "ng-${var.project_slug}-pip-${var.environment_id}-${var.region_code}-${var.sequence}" : null
}

# -----------------------------------------------------------
# NAT Gateway（Public IP Prefixは作成しない）
# -----------------------------------------------------------
resource "azurerm_public_ip" "natgw_pip" {
  provider            = azurerm
  name                = local.name_natgw_pip
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_nat_gateway" "natgw" {
  provider            = azurerm
  name                = local.name_natgw
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  provider             = azurerm
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.natgw_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_natgw_assoc" {
  provider       = azurerm
  subnet_id      = var.subnet_id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "natgw_id"        { value = azurerm_nat_gateway.natgw.id }
output "natgw_public_ip" { value = azurerm_public_ip.natgw_pip.ip_address }
