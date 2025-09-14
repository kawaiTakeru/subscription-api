# ===========================================================
# main.tf 
# ===========================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
    }
  }
}

provider "azapi" {
  use_cli = true
  use_msi = false
}

provider "azurerm" {
  features {}
  alias           = "spoke"
  subscription_id = var.spoke_subscription_id != "" ? var.spoke_subscription_id : null
  tenant_id       = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

locals {
  # サブスクリプション作成はパイプラインから既存を必ず渡すため常にfalse
  need_create_subscription        = false
  effective_spoke_subscription_id = var.spoke_subscription_id

  # プロジェクト・用途名のスラグ化
  project_raw = trimspace(var.project_name)
  purpose_raw = trimspace(var.purpose_name)

  project_slug_base = lower(replace(replace(replace(replace(replace(local.project_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))
  purpose_slug_base = lower(replace(replace(replace(replace(replace(local.purpose_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))

  project_slug = local.project_slug_base
  purpose_slug = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_base
  )

  # 命名規約生成用部品
  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  # リソース命名
  name_rg                  = local.base != "" ? "rg-${local.base}" : null
  name_vnet                = local.base != "" ? "vnet-${local.base}" : null
  name_subnet              = local.project_slug != "" ? "snet-${local.project_slug}-${lower(var.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_nsg                 = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_sr_allow            = local.base != "" ? "sr-${local.base}-001" : null
  name_sr_deny_internet_in = local.base != "" ? "sr-${local.base}-002" : null
  name_vnetpeer_hub2spoke  = local.base != "" ? "vnetpeerhub2spoke-${local.base}" : null
  name_vnetpeer_spoke2hub  = local.base != "" ? "vnetpeerspoke2hub-${local.base}" : null
  name_bastion_nsg         = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_host        = local.project_slug != "" ? "bastion-${local.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_public_ip   = local.project_slug != "" ? "pip-${local.project_slug}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # NATGW/PIP命名を「ng」に統一
  name_natgw     = local.project_slug != "" ? "ng-${local.project_slug}-nat-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_natgw_pip = local.project_slug != "" ? "ng-${local.project_slug}-pip-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # ルートテーブル/UDR命名
  name_route_table = local.base != "" ? "rt-${local.base}" : null
  name_udr_default = local.project_slug != "" ? "udr-${local.project_slug}-er-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms1    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms2    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-002" : null
  name_udr_kms3    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-003" : null

  # Billing Scope（MCA用）
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

  # パブリック・プライベートVNet判定
  is_public  = lower(var.vnet_type) == "public"
  is_private = !local.is_public

  # Bastion 443受信元
  bastion_https_source = local.is_public ? "Internet" : var.vpn_client_pool_cidr

  # --- Public Subnet NSGルール ---
  public_subnet_nsg_rules = [
    {
      name                       = "AllowBastionInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["3389", "22"]
      source_address_prefix      = "*"
      destination_address_prefix = var.bastion_subnet_cidr
      description                = "Bastionの利用に必要な設定を追加"
    },
    {
      name                       = "AllowGatewayManagerInbound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      description                = "Bastionの利用に必要な設定を追加"
    },
    {
      name                       = "AllowAzureLoadBalancerInbound"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
      description                = "Bastionの利用に必要な設定を追加"
    },
    {
      name                       = "AllowBastionHostCommunication"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["8080", "5701"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      description                = "Bastionの利用に必要な設定を追加"
    }
    # デフォルト (65000, 65001, 65500) はAzure自動付与
  ]

  # --- Public Bastion NSGルール ---
  public_bastion_nsg_rules = [
    {
      name                       = "AllowHttpsInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowGatewayManagerInbound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowAzureLoadBalancerInbound"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowBastionHostCommunication"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["8080", "5701"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    },
    # 送信ルール
    {
      name                       = "AllowSshRdpOutbound"
      priority                   = 100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["22", "3389"]
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "AllowAzureCloudOutbound"
      priority                   = 110
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "*"
      destination_address_prefix = "AzureCloud"
    },
    {
      name                       = "AllowBastionCommunication"
      priority                   = 120
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["8080", "5701"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "AllowHttpOutbound"
      priority                   = 130
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["80"]
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
    }
    # デフォルト (65000, 65001, 65500) はAzure自動付与
  ]

  # --- Private Subnet NSGルール ---
  private_subnet_nsg_rules = [
    {
      name                       = "AllowBastionInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["3389", "22"]
      source_address_prefix      = var.kudan_kaikan_ip_range
      destination_address_prefix = var.bastion_subnet_cidr
      description                = "Bastionの利用に必要な設定を追加"
    }
    # デフォルト (65000, 65001, 65500) はAzure自動付与
  ]

  # --- Private Bastion NSGルール ---
  private_bastion_nsg_rules = [
    {
      name                       = "AllowInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "219.54.131.37"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowGatewayManager"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowAzureLoadBalancer"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowBastionHostCommunications"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["8080", "5701"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    },
    # 送信ルール
    {
      name                       = "AllowSshRdpOutbound"
      priority                   = 100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["22", "3389"]
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "AllowAzureCloudOutbound"
      priority                   = 110
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443"]
      source_address_prefix      = "*"
      destination_address_prefix = "AzureCloud"
    },
    {
      name                       = "AllowBastionCommunication"
      priority                   = 120
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_ranges    = ["8080", "5701"]
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    # デフォルト (65000, 65001, 65500) はAzure自動付与
  ]
}

# -----------------------------------------------------------
# Resource Group
# -----------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = local.name_rg
  location = var.region
}

# -----------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# NSG（業務用）
# -----------------------------------------------------------
resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = local.is_public ? { for r in local.public_subnet_nsg_rules : r.name => r }
                               : { for r in local.private_subnet_nsg_rules : r.name => r }
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

# -----------------------------------------------------------
# Bastion用NSG
# -----------------------------------------------------------
resource "azurerm_network_security_group" "bastion_nsg" {
  provider            = azurerm.spoke
  name                = local.name_bastion_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = local.is_public ? { for r in local.public_bastion_nsg_rules : r.name => r }
                               : { for r in local.private_bastion_nsg_rules : r.name => r }
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


# -----------------------------------------------------------
# Resource Group
# -----------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = local.name_rg
  location = var.region
}

# -----------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# NSG（業務用）
# -----------------------------------------------------------
resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# -----------------------------------------------------------
# Bastion用NSG
# -----------------------------------------------------------
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
      destination_address_prefix = security_rule.value.dst
    }
  }
}

# -----------------------------------------------------------
# Subnet（業務用）
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# Subnet（Bastion用/AzureBastionSubnet）
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# NSGアソシエーション
# -----------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

# -----------------------------------------------------------
# Bastion Public IP
# -----------------------------------------------------------
resource "azurerm_public_ip" "bastion_pip" {
  provider            = azurerm.spoke
  name                = local.name_bastion_public_ip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

# -----------------------------------------------------------
# Bastion Host
# -----------------------------------------------------------
resource "azurerm_bastion_host" "bastion" {
  provider            = azurerm.spoke
  name                = local.name_bastion_host
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku         = "Standard"
  scale_units = 2

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  copy_paste_enabled     = false
  file_copy_enabled      = false
  ip_connect_enabled     = false
  shareable_link_enabled = false
  tunneling_enabled      = false
}

# -----------------------------------------------------------
# NAT Gateway構成（パブリック環境のみ）
# -----------------------------------------------------------
resource "azurerm_public_ip" "natgw_pip" {
  count               = local.is_public ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_natgw_pip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_nat_gateway" "natgw" {
  count               = local.is_public ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_natgw
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  count                = local.is_public ? 1 : 0
  provider             = azurerm.spoke
  nat_gateway_id       = azurerm_nat_gateway.natgw[0].id
  public_ip_address_id = azurerm_public_ip.natgw_pip[0].id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_natgw_assoc" {
  count          = local.is_public ? 1 : 0
  provider       = azurerm.spoke
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw[0].id
}

# -----------------------------------------------------------
# ルートテーブル・ルート（プライベート環境のみ）
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# VNet Peering（Hub⇔Spoke）
# -----------------------------------------------------------
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

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "debug_project_name"        { value = var.project_name }
output "debug_purpose_name"        { value = var.purpose_name }
output "debug_project_slug"        { value = local.project_slug }
output "debug_purpose_slug"        { value = local.purpose_slug }
output "debug_base_parts"          { value = local.base_parts }
output "base_naming"               { value = local.base }
output "rg_expected_name"          { value = local.name_rg }
output "vnet_expected_name"        { value = local.name_vnet }
output "subscription_id"           { value = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null }
output "spoke_rg_name"             { value = azurerm_resource_group.rg.name }
output "spoke_vnet_name"           { value = azurerm_virtual_network.vnet.name }
output "hub_to_spoke_peering_id"   { value = azurerm_virtual_network_peering.hub_to_spoke.id }
output "spoke_to_hub_peering_id"   { value = azurerm_virtual_network_peering.spoke_to_hub.id }
output "bastion_host_id"           { value = azurerm_bastion_host.bastion.id }
output "bastion_public_ip"         { value = azurerm_public_ip.bastion_pip.ip_address }
output "natgw_id"                  { value = local.is_public && length(azurerm_nat_gateway.natgw) > 0 ? azurerm_nat_gateway.natgw[0].id : null }
output "natgw_public_ip"           { value = local.is_public && length(azurerm_public_ip.natgw_pip) > 0 ? azurerm_public_ip.natgw_pip[0].ip_address : null }
