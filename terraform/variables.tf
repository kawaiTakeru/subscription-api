#############################################
# Subscription (Stage0 相当)
#############################################
variable "project_name" {
  description = "PJ/案件名（例: bft2）"
  type        = string
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

# サブスクリプション名（未指定なら自動生成: sub-<base>）
variable "subscription_alias_name" {
  description = "内部で使われるサブスクリプションエイリアス名（空なら命名規約で自動生成）"
  type        = string
  default     = ""
}

variable "subscription_display_name" {
  description = "ポータル表示名（空なら命名規約で自動生成）"
  type        = string
  default     = ""
}

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
  description = "既存 Spoke Subscription ID (既存利用時)。新規作成時は Step0 後に pipeline から注入"
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
# Hub 側 (Peering 用)
#############################################
variable "hub_subscription_id" {
  description = "Hub Subscription ID"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub Tenant ID (必要に応じて)"
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

#############################################
# Resource Group (Stage1)
#############################################
variable "region" {
  description = "Azure region (例: japaneast)"
  type        = string
  default     = "japaneast"
}

#############################################
# VNet (Stage2)
#############################################
variable "ipam_pool_id" {
  description = "IPAM Pool Resource ID (VNet/Subnet 共用)"
  type        = string
}

variable "vnet_number_of_ips" {
  description = "VNet に割り当てたい IP 数 (例: 1024 ≒ /22)"
  type        = number
}

#############################################
# Subnet + NSG (Stage3)
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

# Subnet の命名・挙動切替で使用（public/private）
variable "vnet_type" {
  description = "VNet の種別（Subnet 命名の用途欄に使用）。public / private。"
  type        = string
  default     = ""
  validation {
    condition     = var.vnet_type == "" || contains(["public", "private"], lower(trimspace(var.vnet_type)))
    error_message = "vnet_type は ''（空）または 'public' / 'private' を指定してください。"
  }
}
