#############################################
# main.tf（Azure Bastion用NSGのprivate側ルールを追加）
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.41"
    }
  }
}

provider "azapi" {
  use_cli = true
  use_msi = false
}

provider "azurerm" {
  alias           = "spoke"
  features        {}
  subscription_id = var.spoke_subscription_id != "" ? var.spoke_subscription_id : null
  tenant_id       = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  alias           = "hub"
  features        {}
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

locals {
  need_create_subscription        = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )

  project_raw = trimspace(var.project_name)
  purpose_raw = trimspace(var.purpose_name)

  project_slug_base = lower(replace(replace(replace(replace(replace(local.project_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))
  purpose_slug_base = lower(replace(replace(replace(replace(replace(local.purpose_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))

  project_slug = local.project_slug_base
  purpose_slug = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_base
  )

  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  # 命名
  name_rg                   = local.base != "" ? "rg-${local.base}" : null
  name_vnet                 = local.base != "" ? "vnet-${local.base}" : null
  name_subnet               = local.project_slug != "" ? "snet-${local.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_nsg                  = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_vnetpeer_hub2spoke   = local.base != "" ? "vnetpeerhub2spoke-${local.base}" : null
  name_vnetpeer_spoke2hub   = local.base != "" ? "vnetpeerspoke2hub-${local.base}" : null
  name_bastion_nsg          = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # ルートテーブル命名
  name_route_table = local.base != "" ? "rt-${local.base}" : null
  name_udr_default = local.project_slug != "" ? "udr-${local.project_slug}-er-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms1    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms2    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-002" : null
  name_udr_kms3    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-003" : null

  # 課金
  billing_scope = (
    var.billing_account_name != "" &&
    var.billing_profile_name != "" &&
    var.invoice_section_name != ""
  ) ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}" : null

  sub_properties_base = {
    displayName  = var.subscription_display_name != "" ? var.subscription_display_name : (local.base != "" ? "sub-${local.base}" : "")
    workload     = var.subscription_workload
    billingScope = local.billing_scope
  }
  sub_properties_extra = var.management_group_id != "" ? {
    additionalProperties = { managementGroupId = var.management_group_id }
  } : {}
  sub_properties = merge(local.sub_properties_base, local.sub_properties_extra)

  # vnet type
  is_public  = lower(var.vnet_type) == "public"
  is_private = !local.is_public

  # 画像1/2に基づく Bastion 用 NSG ルール
  # 注意: Azure の既定ルール(65000/65001/65500)は自動付与のため定義不要

  # public: 非閉域網（パブリックサブネット）nsg-<pj>-public-bastion-...
  # - Inbound: 100/110/120/130
  # - Outbound: 100/110/120/130（画像1どおり）
  # AllowBastionInbound は宛先 = AzureBastionSubnet の CIDR
  bastion_public_rules = [
    {
      name      = "AllowBastionInbound"
      prio      = 100
      dir       = "Inbound"
      acc       = "Allow"
      proto     = "Tcp"
      src       = "*"
      dst       = "*"   # 実際の宛先CIDRは dst_prefix を使用
      dst_prefix= try(azurerm_subnet.bastion_subnet.address_prefixes[0], azurerm_subnet.bastion_subnet.address_prefix)
      dports    = ["3389","22"]
    },
    {
      name   = "AllowGatewayManagerInbound"
      prio   = 110
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "GatewayManager"
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowAzureLoadBalancerInbound"
      prio   = 120
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "AzureLoadBalancer"
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowBastionHostCommunication"
      prio   = 130
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "*"
      src    = "VirtualNetwork"
      dst    = "VirtualNetwork"
      dports = ["8080","5701"]
    },
    # Outbound（画像1）
    {
      name   = "AllowSshRdpOutbound"
      prio   = 100
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "*"
      dst    = "VirtualNetwork"
      dports = ["22","3389"]
    },
    {
      name   = "AllowAzureCloudOutbound"
      prio   = 110
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "*"
      dst    = "AzureCloud"
      dports = ["443"]
    },
    {
      name   = "AllowBastionCommunicationOutbound"
      prio   = 120
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "VirtualNetwork"
      dst    = "VirtualNetwork"
      dports = ["8080","5701"]
    },
    {
      name   = "AllowHttpOutbound"
      prio   = 130
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "*"
      dst    = "Internet"
      dports = ["80"]
    }
  ]

  # private: 閉域網（AzureBastionSubnet）nsg-<pj>-private-bastion-...
  # Azure 必須ルールを追加（GatewayManager/ALB からの 443）
  bastion_private_rules = [
    {
      name   = "AllowHttpsInbound"
      prio   = 100
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = var.vpn_client_pool_cidr
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowGatewayManagerInbound"
      prio   = 110
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "GatewayManager"
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowAzureLoadBalancerInbound"
      prio   = 120
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "AzureLoadBalancer"
      dst    = "*"
      dports = ["443"]
    }
  ]

  # 実際に適用する Bastion ルール
  bastion_nsg_rules = local.is_public ? local.bastion_public_rules : local.bastion_private_rules

  # 通常 Subnet 用 NSG（前回ご提示に合わせたものを保持）
  normal_nsg_rules = concat(
    [
      {
        name   = "AllowBastionInbound"
        prio   = 100
        dir    = "Inbound"
        acc    = "Allow"
        proto  = "Tcp"
        src    = "VirtualNetwork"
        dst    = "*"
        dports = ["3389","22"]
      }
    ],
    local.is_public ? [
      {
        name   = "AllowGatewayManagerInbound"
        prio   = 110
        dir    = "Inbound"
        acc    = "Allow"
        proto  = "Tcp"
        src    = "GatewayManager"
        dst    = "*"
        dports = ["443"]
      },
      {
        name   = "AllowAzureLoadBalancerInbound"
        prio   = 120
        dir    = "Inbound"
        acc    = "Allow"
        proto  = "Tcp"
        src    = "AzureLoadBalancer"
        dst    = "*"
        dports = ["443"]
      },
      {
        name   = "AllowBastionHostCommunication"
        prio   = 130
        dir    = "Inbound"
        acc    = "Allow"
        proto  = "*"
        src    = "VirtualNetwork"
        dst    = "VirtualNetwork"
        dports = ["8080","5701"]
      }
    ] : []
  )
}

# Subscription Alias（必要時のみ）
resource "azapi_resource" "subscription" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name != "" ? var.subscription_alias_name : (local.base != "" ? "sub-${local.base}" : "")
  parent_id = "/"

  body = jsonencode({
    properties = local.sub_properties
  })

  lifecycle {
    precondition {
      condition     = local.need_create_subscription ? local.billing_scope != null : true
      error_message = "create_subscription=true の場合、billing_account_name / billing_profile_name / invoice_section_name を設定してください（billingScope 必須）。"
    }
  }

  timeouts {
    create = "30m"
    read   = "5m"
    delete = "30m"
  }
}

data "azapi_resource" "subscription_get" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name != "" ? var.subscription_alias_name : (local.base != "" ? "sub-${local.base}" : "")
  parent_id = "/"
  response_export_values = ["properties.subscriptionId"]
  depends_on = [azapi_resource.subscription]
}

# RG
resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = local.name_rg
  location = var.region
}

# VNet
resource "azurerm_virtual_network" "vnet" {
  provider            = azurerm.spoke
  name                = local.name_vnet
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

# 通常 Subnet 用 NSG
resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = { for r in local.normal_nsg_rules : r.name => r }
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.prio
      direction                  = security_rule.value.dir
      access                     = security_rule.value.acc
      protocol                   = security_rule.value.proto
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.dports
      source_address_prefix      = security_rule.value.src
      destination_address_prefix = try(security_rule.value.dst_prefix, security_rule.value.dst)
    }
  }
}

# Bastion 専用 NSG（public/private でルール切替）
resource "azurerm_network_security_group" "bastion_nsg" {
  provider            = azurerm.spoke
  name                = local.name_bastion_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = { for r in local.bastion_nsg_rules : r.name => r }
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.prio
      direction                  = security_rule.value.dir
      access                     = security_rule.value.acc
      protocol                   = security_rule.value.proto
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.dports
      source_address_prefix      = security_rule.value.src
      destination_address_prefix = try(security_rule.value.dst_prefix, security_rule.value.dst)
    }
  }
}

# Subnet（通常）
resource "azurerm_subnet" "subnet" {
  provider             = azurerm.spoke
  name                 = local.name_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.subnet_number_of_ips
  }
}

# Subnet（Azure Bastion 用・固定名）
resource "azurerm_subnet" "bastion_subnet" {
  provider             = azurerm.spoke
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.bastion_subnet_number_of_ips
  }
}

# NSG Association（通常 Subnet）
resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

# NSG Association（Bastion Subnet）
resource "azurerm_subnet_network_security_group_association" "bastion_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

# Route Table（private のみ）
resource "azurerm_route_table" "route_table_private" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_route_table
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route" "route_default_to_gateway" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_default
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_route" "route_kms1" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms1
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "20.118.99.224/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms2" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms2
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "40.83.235.53/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms3" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms3
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "23.102.135.246/32"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "subnet_rt_assoc" {
  count          = local.is_private ? 1 : 0
  provider       = azurerm.spoke
  subnet_id      = azurerm_subnet.subnet.id
  route_table_id = azurerm_route_table.route_table_private[0].id
}

# Peering Hub -> Spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = local.name_vnetpeer_hub2spoke
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${local.effective_spoke_subscription_id}/resourceGroups/${local.name_rg}/providers/Microsoft.Network/virtualNetworks/${local.name_vnet}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network.vnet]
}

# Peering Spoke -> Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.spoke
  name                      = local.name_vnetpeer_spoke2hub
  resource_group_name       = local.name_rg
  virtual_network_name      = local.name_vnet
  remote_virtual_network_id = "/subscriptions/${var.hub_subscription_id}/resourceGroups/${var.hub_rg_name}/providers/Microsoft.Network/virtualNetworks/${var.hub_vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.hub_to_spoke
  ]
}

# Debug outputs
output "debug_project_name"  { value = var.project_name }
output "debug_purpose_name"  { value = var.purpose_name }
output "debug_project_slug"  { value = local.project_slug }
output "debug_purpose_slug"  { value = local.purpose_slug }
output "debug_base_parts"    { value = local.base_parts }
output "base_naming"         { value = local.base }
output "rg_expected_name"    { value = local.name_rg }
output "vnet_expected_name"  { value = local.name_vnet }
output "subscription_id"     { value = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null }
output "spoke_rg_name"       { value = azurerm_resource_group.rg.name }
output "spoke_vnet_name"     { value = azurerm_virtual_network.vnet.name }
output "hub_to_spoke_peering_id" { value = azurerm_virtual_network_peering.hub_to_spoke.id }
output "spoke_to_hub_peering_id" { value = azurerm_virtual_network_peering.spoke_to_hub.id }
