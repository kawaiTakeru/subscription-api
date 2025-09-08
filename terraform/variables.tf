#############################################
# Subscription (Stage0 相当)
#############################################
variable "subscription_alias_name" {
  description = "内部で使われるサブスクリプションエイリアス名"
  type        = string
}
variable "subscription_display_name" {
  description = "ポータル表示名"
  type        = string
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

# 管理グループ（Subscription エイリアス作成時にぶら下げる先）
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

# VNet Peering のリソース名
variable "peering_name_hub_to_spoke" {
  description = "Hub 側に作成するピアリング名"
  type        = string
  default     = "hub-to-spoke"
}
variable "peering_name_spoke_to_hub" {
  description = "Spoke 側に作成するピアリング名"
  type        = string
  default     = "spoke-to-hub"
}

#############################################
# Resource Group (Stage1)
#############################################
variable "rg_name" {
  description = "Resource Group name"
  type        = string
}
variable "location" {
  description = "Azure region"
  type        = string
}

#############################################
# VNet (Stage2)
#############################################
variable "vnet_name" {
  description = "VNet name"
  type        = string
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
# Subnet + NSG (Stage3)
#############################################
variable "subnet_name" {
  description = "Subnet name"
  type        = string
}
variable "subnet_number_of_ips" {
  description = "Subnet に割り当てたい IP 数 (例: 256 ≒ /24)"
  type        = number
}
variable "nsg_name" {
  description = "NSG name"
  type        = string
}

# NSG ルール名
variable "nsg_rule_allow_vpn_name" {
  description = "NSG ルール名 (VPN ポート許可)"
  type        = string
  default     = "Allow-VPN-Port"
}
variable "nsg_rule_deny_internet_name" {
  description = "NSG ルール名 (Internet からの Inbound 拒否)"
  type        = string
  default     = "Deny-Internet-Inbound"
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
