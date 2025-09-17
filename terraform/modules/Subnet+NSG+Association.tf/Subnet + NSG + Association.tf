# ===========================================================
# 変数定義
# ===========================================================
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
variable "vnet_type" { type = string }
variable "ipam_pool_id" { type = string }
variable "subnet_number_of_ips" { type = number }
variable "bastion_subnet_number_of_ips" { type = number }

# 命名用入力
variable "environment_id" { type = string }
variable "region_code" { type = string }
variable "sequence" { type = string }
variable "project_slug" { type = string }

# Optional rule overrides (default handled inside)
variable "public_subnet_nsg_rules" {
  type = list(object({
    name                        = string
    priority                    = number
    direction                   = string
    access                      = string
    protocol                    = string
    source_port_range           = string
    destination_port_ranges     = list(string)
    source_address_prefix       = string
    destination_address_prefix  = string
    description                 = optional(string)
  }))
  default = null
}
variable "private_subnet_nsg_rules" {
  type = list(object({
    name                        = string
    priority                    = number
    direction                   = string
    access                      = string
    protocol                    = string
    source_port_range           = string
    destination_port_ranges     = list(string)
    source_address_prefix       = string
    destination_address_prefix  = string
    description                 = optional(string)
  }))
  default = null
}
variable "public_bastion_nsg_rules" {
  type = list(object({
    name                        = string
    priority                    = number
    direction                   = string
    access                      = string
    protocol                    = string
    source_port_range           = string
    destination_port_ranges     = list(string)
    source_address_prefix       = string
    destination_address_prefix  = string
    description                 = optional(string)
  }))
  default = null
}
variable "private_bastion_nsg_rules" {
  type = list(object({
    name                        = string
    priority                    = number
    direction                   = string
    access                      = string
    protocol                    = string
    source_port_range           = string
    destination_port_ranges     = list(string)
    source_address_prefix       = string
    destination_address_prefix  = string
    description                 = optional(string)
  }))
  default = null
}

# ===========================================================
# locals
# ===========================================================
locals {
  is_public = lower(var.vnet_type) == "public"

  name_subnet      = var.project_slug != "" ? "snet-${var.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_nsg         = var.project_slug != "" ? "nsg-${var.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_nsg = var.project_slug != "" ? "nsg-${var.project_slug}-${lower(var.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # ---- Default rules (single/array fields normalized later in azurerm_network_security_rule) ----
  default_public_subnet_nsg_rules = tolist([
    {
      name = "AllowBastionInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["3389", "22"],
      source_address_prefix = "*", destination_address_prefix = "BASTION_SUBNET",
      description = "Bastionの利用に必要な設定を追加"
    },
    {
      name = "AllowGatewayManagerInbound", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "GatewayManager", destination_address_prefix = "*",
      description = "Bastionの利用に必要な設定を追加"
    },
    {
      name = "AllowAzureLoadBalancerInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*",
      description = "Bastionの利用に必要な設定を追加"
    },
    {
      name = "AllowBastionHostCommunication", priority = 130, direction = "Inbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["8080", "5701"],
      source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork",
      description = "Bastionの利用に必要な設定を追加"
    }
  ])

  default_public_bastion_nsg_rules = tolist([
    {
      name = "AllowHttpsInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "Internet", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowGatewayManagerInbound", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "GatewayManager", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowAzureLoadBalancerInbound", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowBastionHostCommunication", priority = 130, direction = "Inbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["8080", "5701"],
      source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null
    },
    # outbound
    {
      name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["22", "3389"],
      source_address_prefix = "*", destination_address_prefix = "VirtualNetwork", description = null
    },
    {
      name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "*", destination_address_prefix = "AzureCloud", description = null
    },
    {
      name = "AllowBastionCommunication", priority = 120, direction = "Outbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["8080", "5701"],
      source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null
    },
    {
      name = "AllowHttpOutbound", priority = 130, direction = "Outbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["80"],
      source_address_prefix = "*", destination_address_prefix = "Internet", description = null
    }
  ])

  default_private_subnet_nsg_rules = tolist([
    {
      name = "AllowBastionInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["3389", "22"],
      source_address_prefix = "219.54.131.37/32", destination_address_prefix = "BASTION_SUBNET",
      description = "Bastionの利用に必要な設定を追加"
    }
  ])

  default_private_bastion_nsg_rules = tolist([
    {
      name = "AllowInbound", priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "219.54.131.37", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowGatewayManager", priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "GatewayManager", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowAzureLoadBalancer", priority = 120, direction = "Inbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "AzureLoadBalancer", destination_address_prefix = "*", description = null
    },
    {
      name = "AllowBastionHostCommunications", priority = 130, direction = "Inbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["8080", "5701"],
      source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null
    },
    # outbound
    {
      name = "AllowSshRdpOutbound", priority = 100, direction = "Outbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["22", "3389"],
      source_address_prefix = "*", destination_address_prefix = "VirtualNetwork", description = null
    },
    {
      name = "AllowAzureCloudOutbound", priority = 110, direction = "Outbound", access = "Allow", protocol = "Tcp",
      source_port_range = "*", destination_port_ranges = ["443"],
      source_address_prefix = "*", destination_address_prefix = "AzureCloud", description = null
    },
    {
      name = "AllowBastionCommunication", priority = 120, direction = "Outbound", access = "Allow", protocol = "*",
      source_port_range = "*", destination_port_ranges = ["8080", "5701"],
      source_address_prefix = "VirtualNetwork", destination_address_prefix = "VirtualNetwork", description = null
    }
  ])

  effective_public_subnet_nsg_rules   = var.public_subnet_nsg_rules   != null ? var.public_subnet_nsg_rules   : local.default_public_subnet_nsg_rules
  effective_private_subnet_nsg_rules  = var.private_subnet_nsg_rules  != null ? var.private_subnet_nsg_rules  : local.default_private_subnet_nsg_rules
  effective_public_bastion_nsg_rules  = var.public_bastion_nsg_rules  != null ? var.public_bastion_nsg_rules  : local.default_public_bastion_nsg_rules
  effective_private_bastion_nsg_rules = var.private_bastion_nsg_rules != null ? var.private_bastion_nsg_rules : local.default_private_bastion_nsg_rules

  subnet_rules  = local.is_public ? local.effective_public_subnet_nsg_rules  : local.effective_private_subnet_nsg_rules
  bastion_rules = local.is_public ? local.effective_public_bastion_nsg_rules : local.effective_private_bastion_nsg_rules
}

# -----------------------------------------------------------
# Subnets
# -----------------------------------------------------------
resource "azurerm_subnet" "subnet" {
  name                 = local.name_subnet
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

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "subnet_id"             { value = azurerm_subnet.subnet.id }
output "bastion_subnet_id"     { value = azurerm_subnet.bastion_subnet.id }
output "bastion_subnet_prefix" { value = try(azurerm_subnet.bastion_subnet.address_prefixes[0], null) }

# -----------------------------------------------------------
# NSGs (no inline rules)
# -----------------------------------------------------------
resource "azurerm_network_security_group" "subnet_nsg" {
  name                = local.name_nsg
  location            = var.region
  resource_group_name = var.rg_name
}

resource "azurerm_network_security_group" "bastion_nsg" {
  name                = local.name_bastion_nsg
  location            = var.region
  resource_group_name = var.rg_name
}

output "subnet_nsg_id"  { value = azurerm_network_security_group.subnet_nsg.id }
output "bastion_nsg_id" { value = azurerm_network_security_group.bastion_nsg.id }

# -----------------------------------------------------------
# NSG Rules (per-resource; avoids inline set correlation issues)
# -----------------------------------------------------------

# Subnet NSG rules
resource "azurerm_network_security_rule" "subnet_rules" {
  for_each = { for r in local.subnet_rules : r.name => r }

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol

  source_port_range           = each.value.source_port_range
  destination_port_range      = length(each.value.destination_port_ranges) == 1 ? each.value.destination_port_ranges[0] : null
  destination_port_ranges     = length(each.value.destination_port_ranges) > 1  ? each.value.destination_port_ranges    : null

  source_address_prefix       = each.value.source_address_prefix

  # 重要: "BASTION_SUBNET" は Bastion サブネットの実CIDRに置換
  # 単一値フィールド/配列フィールドを正しく使い分けて null index を回避
  destination_address_prefix  = (
    each.value.destination_address_prefix == "BASTION_SUBNET" ? null : each.value.destination_address_prefix
  )

  destination_address_prefixes = (
    each.value.destination_address_prefix == "BASTION_SUBNET" ? azurerm_subnet.bastion_subnet.address_prefixes : null
  )

  description                 = try(each.value.description, null)

  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.subnet_nsg.name

  depends_on = [azurerm_network_security_group.subnet_nsg, azurerm_subnet.bastion_subnet]
}

# Bastion NSG rules
resource "azurerm_network_security_rule" "bastion_rules" {
  for_each = { for r in local.bastion_rules : r.name => r }

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol

  source_port_range           = each.value.source_port_range
  destination_port_range      = length(each.value.destination_port_ranges) == 1 ? each.value.destination_port_ranges[0] : null
  destination_port_ranges     = length(each.value.destination_port_ranges) > 1  ? each.value.destination_port_ranges    : null

  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  description                 = try(each.value.description, null)

  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name

  depends_on = [azurerm_network_security_group.bastion_nsg]
}

# -----------------------------------------------------------
# NSG Associations
# -----------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion_assoc" {
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}
