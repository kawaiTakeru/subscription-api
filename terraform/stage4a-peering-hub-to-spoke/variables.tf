variable "hub_vnet_name" {
  type        = string
  description = "Hub VNet name"
}

variable "hub_rg_name" {
  type        = string
  description = "Hub RG name"
}

variable "spoke_vnet_name" {
  type        = string
  description = "Spoke VNet name (from Stage2)"
}

variable "spoke_rg_name" {
  type        = string
  description = "Spoke RG name (from Stage2)"
}

variable "spoke_subscription_id" {
  type        = string
  description = "Spoke subscription ID (from Stage0)"
}
