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
# VNet種別（public/private）: ルール切替に利用
# -----------------------------------------------------------
variable "vnet_type" {
  description = "VNet種別（public/private）"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], lower(var.vnet_type))
    error_message = "vnet_type は public / private のいずれかにしてください。"
  }
}

variable "project_slug" {
  type        = string
}

variable "resource_group_location" {
  type        = string
}

variable "resource_group_name" {
  type        = string
}

variable "bastion_subnet_id" {
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
  name_bastion_host        = var.project_slug != "" ? "bas-${var.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_public_ip   = var.project_slug != "" ? "pip-${var.project_slug}-bas-${var.environment_id}-${var.region_code}-${var.sequence}" : null
}

# -----------------------------------------------------------
# Bastion Public IP
# -----------------------------------------------------------
resource "azurerm_public_ip" "bastion_pip" {
  provider            = azurerm
  name                = local.name_bastion_public_ip
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

# -----------------------------------------------------------
# Bastion Host
# -----------------------------------------------------------
resource "azurerm_bastion_host" "bastion" {
  provider            = azurerm
  name                = local.name_bastion_host
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  sku         = "Standard"
  scale_units = 2

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  copy_paste_enabled     = false
  file_copy_enabled      = false
  ip_connect_enabled     = false
  shareable_link_enabled = false
  tunneling_enabled      = false
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "bastion_host_id"           { value = azurerm_bastion_host.bastion.id }
output "bastion_public_ip"         { value = azurerm_public_ip.bastion_pip.ip_address }
