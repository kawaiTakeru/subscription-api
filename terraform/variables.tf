#############################################
# Naming inputs（この2つを変えれば全命名が変わる）
#############################################
variable "project_name" {
  description = "PJ/案件名（例: BFT）"
  type        = string
}

variable "purpose_name" {
  description = "用途（例: 検証 / 本番 など）"
  type        = string
}

variable "environment_id" {
  description = "環境識別子（例: prd, stg, dev）"
  type        = string
  default     = "prd"
}

variable "region" {
  description = "Azure region (例: japaneast)"
  type        = string
  default     = "japaneast"
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
# Subscription (Step0)
#############################################
variable "billing_account_name" {
  description = "課金アカウント名"
  type        = string
}

variable "billing_profile_name" {
  description = "課金プロファイル名"
  type        = string
}

variable "invoice_section_name" {
  description = "請求セクション名"
  type        = string
}

variable "subscription_workload" {
  description = "Workload 種別 (Production / DevTest)"
  type        = string
  default     = "Production"
}

variable "create_subscription" {
  description = "サブスクリプション(エイリアス)を新規作成するか (spoke_subscription_id 空の場合のみ有効)"
  type        = bool
  default     = true
}

variable "enable_billing_check" {
  description = "Billing 読み取りチェック (未使用: 将来拡張用)"
  type        = bool
  default     = false
}

variable "spoke_subscription_id" {
  description = "既存 Spoke Subscription ID（既存利用時）。新規作成時は Step0 後に pipeline から注入"
  type        = string
  default     = ""
}

variable "spoke_tenant_id" {
  description = "Spoke Tenant ID (必要に応じて)"
  type        = string
  default     = ""
}

variable "management_group_id" {
  description = "管理グループのリソースID (/providers/Microsoft.Management/managementGroups/<mg-name>)"
  type        = string
  default     = "/providers/Microsoft.Management/managementGroups/mg-bft-test"
}

#############################################
# Hub 側 (Peering 用) - 既存参照
#############################################
variable "hub_subscription_id" {
  description = "Hub Subscription ID（既存参照）"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub Tenant ID (必要に応じて)"
  type        = string
  default     = ""
}

variable "hub_vnet_name" {
  description = "Hub VNet name（既存参照）"
  type        = string
}

variable "hub_rg_name" {
  description = "Hub Resource Group name（既存参照）"
  type        = string
}

#############################################
# VNet / Subnet / NSG Inputs
#############################################
variable "ipam_pool_id" {
  description = "IPAM Pool Resource ID (VNet/Subnet 共用)"
  type        = string
}

variable "vnet_number_of_ips" {
  description = "VNet に割り当てたい IP 数 (例: 1024 ≒ /22)"
  type        = number
}

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
