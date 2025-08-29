# 既存のリソースグループ
variable "rg_name" {
  type        = string
  description = "Resource Group name (existing)"
}

# 既存の VNet
variable "vnet_name" {
  type        = string
  description = "VNet name (existing)"
}

# これから作る Subnet 名
variable "subnet_name" {
  type        = string
  description = "Subnet name"
}

# Subnet も IPAM から割当
variable "ipam_pool_id" {
  description = "Resource ID of IPAM pool to allocate Subnet space from"
  type        = string
}

# 割り当てたい IP 数（例：256 ≒ /24）
variable "subnet_number_of_ips" {
  description = "How many IPs to allocate to the Subnet (e.g. 256 ≒ /24)"
  type        = number
}

# NSG 名
variable "nsg_name" {
  type        = string
  description = "NSG name"
}

# VPN クライアントプールの CIDR（許可元）
variable "vpn_client_pool_cidr" {
  type        = string
  description = "VPN client pool CIDR for allow-rule"
}

# 許可ポート（RDP=3389 / SSH=22 など）
variable "allowed_port" {
  type        = number
  description = "Allowed port from VPN clients (3389 for RDP, 22 for SSH)"
  default     = 3389
}
