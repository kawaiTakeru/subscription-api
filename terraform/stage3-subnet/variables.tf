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

variable "subnet_prefixes" {
  type        = list(string)
  description = "Subnet CIDR(s)"
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
