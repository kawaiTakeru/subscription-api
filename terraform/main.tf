#############################################
# main.tf（命名規約: <識別子>-<PJ>-<用途>-<環境>-<region_code>-<通番>）
#############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azapi  = { source = "azure/azapi",     version = "~> 1.15" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.41" }
  }
}

provider "azapi" { use_cli = true, use_msi = false }

provider "azurerm" {
  alias            = "spoke"
  features         {}
  subscription_id  = var.spoke_subscription_id != "" ? var.spoke_subscription_id : null
  tenant_id        = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  alias            = "hub"
  features         {}
  subscription_id  = var.hub_subscription_id
  tenant_id        = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

locals {
  # Subscription creation flow
  need_create_subscription        = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )

  # 命名: base（スラッグ化: 英数字のみ・小文字）
  project_slug      = lower(join("", regexall(var.project_name, "[A-Za-z0-9]")))
  purpose_slug_base = lower(join("", regexall(var.purpose_name, "[A-Za-z0-9]")))
  purpose_slug      = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    var.purpose_name == "検証" ? "kensho" : local.purpose_slug_base
  )
  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  # サブスクリプション命名（未指定なら規約で自動作成）
  name_sub_alias   = var.subscription_alias_name   != "" ? var.subscription_alias_name   : (local.base != "" ? "sub-${local.base}" : "")
  name_sub_display = var.subscription_display_name != "" ? var.subscription_display_name : (local.base != "" ? "sub-${local.base}" : "")

  # 各リソース名（命名規約準拠）
  name_rg                  = local.base != "" ? "rg-${local.base}" : null
  name_vnet                = local.base != "" ? "vnet-${local.base}" : null
  name_subnet              = local.base != "" ? "snet-${local.base}" : null
  name_nsg                 = local.base != "" ? "nsg-${local.base}" : null
  name_sr_allow            = local.base != "" ? "sr-${local.base}-001" : null
  name_sr_deny_internet_in = local.base != "" ? "sr-${local.base}-002" : null
  name_vnetpeer_hub2spoke  = local.base != "" ? "vnetpeerhub2spoke-${local.base}" : null
  name_vnetpeer_spoke2hub  = local.base != "" ? "vnetpeerspoke2hub-${local.base}" : null
}

# Subscription Alias（必要時のみ）
resource "azapi_resource" "subscription" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = local.name_sub_alias
  parent_id = "/"
  body = jsonencode({
    properties = {
      displayName  = local.name_sub_display
      workload     = var.subscription_workload
      additionalProperties = { managementGroupId = var.management_group_id }
    }
  })
  timeouts { create = "30m", read = "5m", delete = "30m" }
}

data "azapi_resource" "subscription_get" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = local.name_sub_alias
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

# NSG
resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = local.name_sr_allow
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.allowed_port
    source_address_prefix      = var.vpn_client_pool_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = local.name_sr_deny_internet_in
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# Subnet
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

# NSG Association
resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
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

# Debug outputs（命名確認）
output "base_naming"       { value = local.base }
output "rg_expected_name"  { value = local.name_rg }
output "vnet_expected_name"{ value = local.name_vnet }

output "subscription_id"   { value = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null }
output "spoke_rg_name"     { value = azurerm_resource_group.rg.name }
output "spoke_vnet_name"   { value = azurerm_virtual_network.vnet.name }
output "hub_to_spoke_peering_id" { value = azurerm_virtual_network_peering.hub_to_spoke.id }
output "spoke_to_hub_peering_id" { value = azurerm_virtual_network_peering.spoke_to_hub.id }
