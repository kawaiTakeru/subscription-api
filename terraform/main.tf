#############################################
# main.tf
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
  alias    = "spoke"
  features {}
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
  # Billing scope
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"

  # Subscription creation flow
  need_create_subscription        = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )

  # Slug from project/purpose (ASCII のみ)
  project_slug       = lower(regexreplace(var.project_name, "[^a-zA-Z0-9]", ""))
  purpose_slug_base  = lower(regexreplace(var.purpose_name, "[^a-zA-Z0-9]", ""))
  purpose_slug       = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    var.purpose_name == "検証" ? "kensho" : local.purpose_slug_base
  )

  # 基本名: <proj>-<purpose>-<env>-<region>-<seq>
  base = "${local.project_slug}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}"

  # 各リソース名
  name_sub_alias   = "sub-${local.base}"
  name_sub_display = "sub-${var.purpose_name}-${var.environment_id}-${var.region_code}-${var.sequence}" # 表示名は日本語用途可
  name_rg          = "rg-${local.base}"
  name_vnet        = "vnet-${local.base}"
  name_subnet      = "snet-${local.base}"
  name_nsg         = "nsg-${local.base}"
  name_peer        = "peer-${local.base}"                  # Hub側/Spoke側で同一名でも問題なし（各VNet内で一意）

  # NSG ルール名（命名規則に従いつつ通番で区別）
  nsg_rule_allow_name = "nsgr-${local.base}-001"
  nsg_rule_deny_name  = "nsgr-${local.base}-002"
}

resource "azapi_resource" "subscription" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = local.name_sub_alias
  parent_id = "/"
  body = jsonencode({
    properties = {
      displayName  = local.name_sub_display
      billingScope = local.billing_scope
      workload     = var.subscription_workload

      # 管理グループ配下に作成（変数化）
      additionalProperties = {
        managementGroupId = var.management_group_id
      }
    }
  })
  timeouts {
    create = "30m"
    read   = "5m"
    delete = "30m"
  }
}

data "azapi_resource" "subscription_get" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = local.name_sub_alias
  parent_id = "/"
  response_export_values = ["properties.subscriptionId"]
  depends_on = [azapi_resource.subscription]
}

resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = local.name_rg
  location = var.region
}

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

resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = local.nsg_rule_allow_name
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
    name                       = local.nsg_rule_deny_name
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

resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = local.name_peer
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
  name                      = local.name_peer
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

output "subscription_id" {
  value       = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null
  description = "Effective subscription ID"
}

output "spoke_rg_name" {
  value = azurerm_resource_group.rg.name
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "hub_to_spoke_peering_id" {
  value = azurerm_virtual_network_peering.hub_to_spoke.id
}

output "spoke_to_hub_peering_id" {
  value = azurerm_virtual_network_peering.spoke_to_hub.id
}
