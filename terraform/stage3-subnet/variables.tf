variable "rg_name"      { type = string }
variable "vnet_name"    { type = string }
variable "subnet_name"  { type = string }

# 追加：Subnet も IPAM から割当
variable "ipam_pool_id" {
  description = "Resource ID of IPAM pool to allocate Subnet space from"
  type        = string
}
variable "subnet_number_of_ips" {
  description = "How many IPs to allocate to the Subnet (e.g. 256 ≒ /24相当)"
  type        = string
}

variable "nsg_name"            { type = string }
variable "vpn_client_pool_cidr"{ type = string }
variable "allowed_port"        { type = number  default = 3389 }
