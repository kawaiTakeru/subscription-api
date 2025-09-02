#############################################
# main.tf (修正済み / BFT-TEST 管理グループ配下に作成)
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
  billing_scope                    = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"
  need_create_subscription         = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id  = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )
}

resource "azapi_resource" "subscription" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name
  parent_id = "/"
  body = jsonencode({
    properties = {
      displayName  = var.subscription_display_name
      billingScope = local.billing_scope
      workload     = var.subscription_workload

      # ★ BFT-TEST 管理グループ配下に作成 ★
      additionalProperties = {
        managementGroupId = "/providers/Microsoft.Management/managementGroups/mg-bft-test"
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
  name      = var.subscription_alias_name
  parent_id = "/"
  response_export_values = ["properties.subscriptionId"]
  depends_on = [azapi_resource.subscription]
}

resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = var.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  provider            = azurerm.spoke
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = var.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-VPN-Port"
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
    name                       = "Deny-Internet-Inbound"
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
  name                 = var.subnet_name
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
  name                      = "hub-to-spoke"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${local.effective_spoke_subscription_id}/resourceGroups/${var.rg_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.spoke
  name                      = "spoke-to-hub"
  resource_group_name       = var.rg_name
  virtual_network_name      = var.vnet_name
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
