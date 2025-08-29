variable "rg_name" {
  description = "Resource Group name (existing)"
  type        = string
}

variable "vnet_name" {
  description = "VNet name"
  type        = string
}

variable "ipam_pool_id" {
  description = "Resource ID of IPAM pool to allocate VNet space from"
  type        = string
}

variable "vnet_number_of_ips" {
  description = "How many IPs to allocate to the VNet (e.g. 1024 ≒ /22)"
  type        = number
}

# ★ 追加：Terraform が必ずこの Subscription を使うように明示
variable "subscription_id" {
  description = "Target Azure Subscription ID for this stage"
  type        = string
}
