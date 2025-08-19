variable "spoke_vnet_name" {
  type        = string
  description = "Spoke VNet name (from Stage2)"
}

variable "spoke_rg_name" {
  type        = string
  description = "Spoke RG name (from Stage2)"
}

variable "hub_vnet_name" {
  type        = string
  description = "Hub VNet name (from tfvars)"
}

variable "hub_rg_name" {
  type        = string
  description = "Hub RG name (from tfvars)"
}

variable "hub_subscription_id" {
  type        = string
  description = "Hub subscription ID (from tfvars)"
}
