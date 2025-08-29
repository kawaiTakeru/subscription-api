variable "rg_name" {
  description = "Resource Group name (existing)"
  type        = string
}
variable "vnet_name" {
  description = "VNet name"
  type        = string
}

# 追加：IPAMプールID と VNetに欲しいIP数
variable "ipam_pool_id" {
  description = "Resource ID of IPAM pool to allocate VNet space from"
  type        = string
}
variable "vnet_number_of_ips" {
  description = "How many IPs to allocate to the VNet (e.g. 1024 ≒ /22相当)"
  type        = string
}
