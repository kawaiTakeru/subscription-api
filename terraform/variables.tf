#############################################
# 命名用 変数
#############################################
variable "project_name" {
  description = "PJ/案件名（例: bft2）"
  type        = string
  default     = ""
  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name は必須です。例: bft2"
  }
}

variable "purpose_name" {
  description = "用途（例: kensho2 / 検証 など）"
  type        = string
  default     = ""
  validation {
    condition     = length(trimspace(var.purpose_name)) > 0
    error_message = "purpose_name は必須です。例: kensho2"
  }
}

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
  description = "識別番号（ゼロ埋め文字列推奨: 001）"
  type        = string
  default     = "001"
}

#############################################
# Resource Group / VNet
#############################################
variable "region" {
  description = "Azure region (例: japaneast)"
  type        = string
  default     = "japaneast"
}

variable "ipam_pool_id" {
  description = "IPAM Pool Resource ID (VNet/Subnet 共用)"
  type        = string
}

variable "vnet_number_of_ips" {
  description = "VNet に割り当てたい IP 数 (例: 1024 ≒ /22)"
  type        = number
}

#############################################
# Subnet + NSG
#############################################
variable "subnet_number_of_ips" {
  description = "Subnet に割り当てたい IP 数 (例: 256 ≒ /24)"
  type        = number
}

variable "vpn_client_pool_cidr" {
  description = "VPN クライアントプール CIDR (許可元)"
  type        = string
}

variable "allowed_port" {
  description = "許可ポート (RDP=3389 / SSH=22 など)"
  type        = number
  default     = 3389
}

#############################################
# Hub / Spoke Subscriptions
#############################################
variable "spoke_subscription_id" {
  description = "既存 Spoke Subscription ID（必須）"
  type        = string
}

variable "spoke_tenant_id" {
  description = "Spoke Tenant ID（必要に応じて）"
  type        = string
  default     = ""
}

variable "hub_subscription_id" {
  description = "Hub Subscription ID（必須）"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub Tenant ID（必要に応じて）"
  type        = string
  default     = ""
}

variable "hub_vnet_name" {
  description = "Hub VNet name"
  type        = string
}

variable "hub_rg_name" {
  description = "Hub Resource Group name"
  type        = string
}
