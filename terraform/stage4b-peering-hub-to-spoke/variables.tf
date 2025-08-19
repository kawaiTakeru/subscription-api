variable "spoke_vnet_name" {
  description = "Spoke VNet name (auto-injected via TF_VAR_spoke_vnet_name)"
  type        = string
}

variable "spoke_rg_name" {
  description = "Spoke Resource Group name (auto-injected via TF_VAR_spoke_rg_name)"
  type        = string
}

variable "hub_vnet_name" {
  description = "Hub VNet name"
  type        = string
}

variable "hub_rg_name" {
  description = "Hub Resource Group name"
  type        = string
}

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
}
