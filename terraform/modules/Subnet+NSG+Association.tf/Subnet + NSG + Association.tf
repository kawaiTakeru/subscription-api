terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
    }
  }
}

variable "spoke_subscription_id" { type = string }
variable "spoke_tenant_id" { type = string }
variable "rg_name" { type = string }
variable "region" { type = string }
variable "vnet_name" { type = string }
variable "name_subnet" { type = string }
variable "name_nsg" { type = string }
variable "name_bastion_nsg" { type = string }
variable "vnet_type" { type = string }
variable "ipam_pool_id" { type = string }
variable "subnet_number_of_ips" { type = number }
variable "bastion_subnet_number_of_ips" { type = number }

# Optional rule overrides (default handled inside)
variable "public_subnet_nsg_rules" {
  type    = list(object({
    name = string, priority = number, direction = string, access = string, protocol = string,
    source_port_range = string, destination_port_ranges = list(string), source_address_prefix = string,
    destination_address_prefix = string, description = optional(string)
  }))
  default = null
}
variable "private_subnet_nsg_rules" {
  type    = list(object({
    name = string, priority = number, direction = string, access = string, protocol = string,
    source_port_range = string, destination_port_ranges = list(string), source_address_prefix = string,
    destination_address_prefix = string, description = optional(string)
  }))
  default = null
}
variable "public_bastion_nsg_rules" {
  type    = list(object({
    name = string, priority = number, direction = string, access = string, protocol = string,
    source_port_range = string, destination_port_ranges = list(string), source_address_prefix = string,
    destination_address_prefix = string, description = optional(string)
  }))
  default = null
}
variable "private_bastion_nsg_rules" {
  type    = list(object({
    name = string, priority = number, direction = string, access = string, protocol = string,
    source_port_range = string, destination_port_ranges = list(string), source_address_prefix = string,
    destination_address_prefix = string, description = optional(string)
  }))
  default = null
}

locals {
  is_public = lower(var.vnet_type) == "public"

  default_public_subnet_nsg_rules = tolist([
    { name = "AllowBastionInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["3389", "22"], source_address_prefix = "*", destination_address_prefix = "BASTION_SUBNET", description = "Bastionの利用に必要な設定を追加" },
    { name = "AllowGatewayManagerInbound", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "GatewayManager", destination_address_prefix = "*", description = "Bastionの利用に必要な設定を追加" },
    { name = "AllowAzureLoadBalancerInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*", description = "Bastionの利用に必要な設定を追加" },
    { name = "AllowBastionHostCommunication", priority = 130, direction = "Inbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = "Bastionの利用に必要な設定を追加" }
  ])
  default_public_bastion_nsg_rules = tolist([
    { name = "AllowHttpsInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "Internet", destination_address_prefix = "*", description = null },
    { name = "AllowGatewayManagerInbound", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "GatewayManager", destination_address_prefix = "*", description = null },
    { name = "AllowAzureLoadBalancerInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*", description = null },
    { name = "AllowBastionHostCommunication", priority = 130, direction = "Inbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null },
    { name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["22", "3389"], source_address_prefix = "*", destination_address_prefix = "VirtualNetwork", description = null },
    { name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "*", destination_address_prefix = "AzureCloud", description = null },
    { name = "AllowBastionCommunication", priority = 120, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null },
    { name = "AllowHttpOutbound", priority = 130, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["80"], source_address_prefix = "*", destination_address_prefix = "Internet", description = null }
  ])
  default_private_subnet_nsg_rules = tolist([
    { name = "AllowBastionInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["3389", "22"], source_address_prefix = "219.54.131.37", destination_address_prefix = "BASTION_SUBNET", description = "Bastionの利用に必要な設定を追加" }
  ])
  default_private_bastion_nsg_rules = tolist([
    { name = "AllowInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "219.54.131.37", destination_address_prefix = "*", description = null },
    { name = "AllowGatewayManager", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "GatewayManager", destination_address_prefix = "*", description = null },
    { name = "AllowAzureLoadBalancer", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*", description = null },
    { name = "AllowBastionHostCommunications", priority = 130, direction = "Inbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null },
    { name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["22", "3389"], source_address_prefix = "*", destination_address_prefix = "VirtualNetwork", description = null },
    { name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_ranges = ["443"], source_address_prefix = "*", destination_address_prefix = "AzureCloud", description = null },
    { name = "AllowBastionCommunication", priority = 120, direction = "Outbound", access = "Allow", protocol = "*", source_port_range = "*", destination_port_ranges = ["8080", "5701"], source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null }
  ])

  effective_public_subnet_nsg_rules   = var.public_subnet_nsg_rules   != null ? var.public_subnet_nsg_rules   : local.default_public_subnet_nsg_rules
  effective_private_subnet_nsg_rules  = var.private_subnet_nsg_rules  != null ? var.private_subnet_nsg_rules  : local.default_private_subnet_nsg_rules
  effective_public_bastion_nsg_rules  = var.public_bastion_nsg_rules  != null ? var.public_bastion_nsg_rules  : local.default_public_bastion_nsg_rules
  effective_private_bastion_nsg_rules = var.private_bastion_nsg_rules != null ? var.private_bastion_nsg_rules : local.default_private_bastion_nsg_rules
}

resource "azurerm_subnet" "subnet" {
  name                 = var.name_subnet
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.subnet_number_of_ips
  }
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.bastion_subnet_number_of_ips
  }
}

output "subnet_id" { value = azurerm_subnet.subnet.id }
output "bastion_subnet_id" { value = azurerm_subnet.bastion_subnet.id }
output "bastion_subnet_prefix" { value = try(azurerm_subnet.bastion_subnet.address_prefixes[0], null) }

resource "azurerm_network_security_group" "subnet_nsg" {
  name                = var.name_nsg
  location            = var.region
  resource_group_name = var.rg_name
  dynamic "security_rule" {
    for_each = local.is_public ? { for r in local.effective_public_subnet_nsg_rules : r.name => r } : { for r in local.effective_private_subnet_nsg_rules : r.name => r }
    content {
      name                      = security_rule.value.name
      priority                  = security_rule.value.priority
      direction                 = security_rule.value.direction
      access                    = security_rule.value.access
      protocol                  = security_rule.value.protocol
      source_port_range         = security_rule.value.source_port_range
      destination_port_ranges   = security_rule.value.destination_port_ranges
      source_address_prefix     = security_rule.value.source_address_prefix
      destination_address_prefix = (
        security_rule.value.destination_address_prefix == "BASTION_SUBNET"
  ? try(azurerm_subnet.bastion_subnet.address_prefixes[0], "VirtualNetwork")
        : security_rule.value.destination_address_prefix
      )
      description = lookup(security_rule.value, "description", null)
    }
  }
}

resource "azurerm_network_security_group" "bastion_nsg" {
  name                = var.name_bastion_nsg
  location            = var.region
  resource_group_name = var.rg_name
  dynamic "security_rule" {
    for_each = local.is_public ? { for r in local.effective_public_bastion_nsg_rules : r.name => r } : { for r in local.effective_private_bastion_nsg_rules : r.name => r }
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_ranges    = security_rule.value.destination_port_ranges
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
      description                = lookup(security_rule.value, "description", null)
    }
  }
}

output "subnet_nsg_id" { value = azurerm_network_security_group.subnet_nsg.id }
output "bastion_nsg_id" { value = azurerm_network_security_group.bastion_nsg.id }

resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion_assoc" {
  count                     = 1
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}
