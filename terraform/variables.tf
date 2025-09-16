# ===========================================================
# 変数定義
# ===========================================================

# -----------------------------------------------------------
# サブスクリプション・命名規約関連（Stage0相当）
# -----------------------------------------------------------
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
  description = "リソース名の通番（ゼロ埋め文字列推奨: 001）"
  type        = string
  default     = "001"
}

# サブスクリプション生成時のエイリアス名（未指定時は命名規約で自動生成）
variable "subscription_alias_name" {
  description = "サブスクリプションエイリアス名（命名規約で自動生成可）"
  type        = string
  default     = ""
}

# サブスクリプションのポータル表示用名（未指定時は命名規約で自動生成）
variable "subscription_display_name" {
  description = "サブスクリプションのポータル表示名（命名規約で自動生成可）"
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# 課金系パラメータ（MCA用）
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# Workload種別（Production / DevTest）
# -----------------------------------------------------------
variable "subscription_workload" {
  description = "Workload種別 (Production / DevTest)"
  type        = string
  default     = "Production"
}

# -----------------------------------------------------------
# サブスクリプション新規作成フラグ（既存流用の場合はfalse）
# -----------------------------------------------------------
variable "create_subscription" {
  description = "サブスクリプション（エイリアス）新規作成可否"
  type        = bool
  default     = true
}

# -----------------------------------------------------------
# 将来の拡張用（現状未使用）
# -----------------------------------------------------------
variable "enable_billing_check" {
  description = "課金情報の読み取りチェック（未使用／将来拡張用）"
  type        = bool
  default     = false
}

# -----------------------------------------------------------
# Spokeサブスクリプション／テナント
# -----------------------------------------------------------
variable "spoke_subscription_id" {
  description = "Spoke Subscription ID（既存利用時、pipeline注入）"
  type        = string
  default     = ""
}

variable "spoke_tenant_id" {
  description = "Spoke Tenant ID（必要時のみ）"
  type        = string
  default     = ""
}

# -----------------------------------------------------------
# 管理グループ
# -----------------------------------------------------------
variable "management_group_id" {
  description = "管理グループのリソースID（/providers/Microsoft.Management/managementGroups/<mg-name>）"
  type        = string
  default     = "/providers/Microsoft.Management/managementGroups/mg-bft-test"
}

# -----------------------------------------------------------
# Hub情報（Peering用）
# -----------------------------------------------------------
variable "hub_subscription_id" {
  description = "Hub Subscription ID"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub Tenant ID（必要時のみ）"
  type        = string
  default     = ""
}

variable "hub_vnet_name" {
  description = "Hub側のVNet名"
  type        = string
}

variable "hub_rg_name" {
  description = "Hub側のリソースグループ名"
  type        = string
}

# -----------------------------------------------------------
# Resource Group（Stage1）
# -----------------------------------------------------------
variable "region" {
  description = "Azure配置リージョン（例: japaneast）"
  type        = string
  default     = "japaneast"
}

# -----------------------------------------------------------
# VNet（Stage2）
# -----------------------------------------------------------
variable "ipam_pool_id" {
  description = "IPAM Pool Resource ID（VNet/Subnet共用）"
  type        = string
}

variable "vnet_number_of_ips" {
  description = "VNetに割り当てるIP数（例: 1024≒/22）"
  type        = number
}

# -----------------------------------------------------------
# Subnet + NSG（Stage3）
# -----------------------------------------------------------
variable "subnet_number_of_ips" {
  description = "Subnetに割り当てるIP数（例: 256≒/24）"
  type        = number
}

# Bastion用SubnetのIP数（推奨/26=64 IP）
variable "bastion_subnet_number_of_ips" {
  description = "AzureBastionSubnetのIP数（推奨: 64≒/26）"
  type        = number
  default     = 64
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

# -----------------------------------------------------------
# VPNクライアントプールCIDR（許可元）/ 許可ポート
# -----------------------------------------------------------
variable "vpn_client_pool_cidr" {
  description = "VPNクライアントプールCIDR（許可元）"
  type        = string
}

variable "allowed_port" {
  description = "サブネットで許可するポート番号（例: RDP=3389, SSH=22 等）"
  type        = number
  default     = 3389
}

# -----------------------------------------------------------
# サブスクリプションの所有者に付与するユーザー（メール/UPN一覧）
# -----------------------------------------------------------
variable "subscription_owner_emails" {
  description = "Subscription Owner に付与するユーザーのメール（UPN）一覧（例: [\"alice@example.com\"]）"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------
# PIM 承認者グループ（既存グループの displayName を指定）
# -----------------------------------------------------------
variable "pim_owner_approver_group_names" {
  description = "PIM(Owner)の承認者に設定するグループ displayName 一覧（既存グループを指定）"
  type        = list(string)
  default     = []
}

variable "pim_contributor_approver_group_names" {
  description = "PIM(Contributor)の承認者に設定するグループ displayName 一覧（既存グループを指定）"
  type        = list(string)
  default     = []
}
