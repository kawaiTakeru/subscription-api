variable "rg_name" {
  type        = string
  description = "Resource Group name (existing)"
}

variable "vnet_name" {
  type        = string
  description = "VNet name (existing)"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name"
}

# Subnet も IPAM から割当
variable "ipam_pool_id" {
  description = "Resource ID of IPAM pool to allocate Subnet space from"
  type        = string
}

variable "subnet_number_of_ips" {
  description = "How many IPs to allocate to the Subnet (e.g. 256 ≒ /24)"
  type        = number
}

variable "nsg_name" {
  type        = string
  description = "NSG name"
}

variable "vpn_client_pool_cidr" {
  type        = string
  description = "VPN client pool CIDR for allow-rule"
}

variable "allowed_port" {
  type        = number
  description = "Allowed port from VPN clients (3389 for RDP, 22 for SSH)"
  default     = 3389
}
