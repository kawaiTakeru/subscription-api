#############################################
# Combined Terraform (Stages 0 ~ 4b)
# - Step0: Subscription (AzAPI)
# - Step1: Resource Group
# - Step2: Virtual Network (IPAM)
# - Step3: Subnet + NSG + Association (IPAM)
# - Step4a: Peering Hub -> Spoke
# - Step4b: Peering Spoke -> Hub
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

#############################################
# Providers
#############################################

# Azure CLI 認証 (パイプラインで ARM_USE_AZCLI_AUTH=true)
provider "azapi" {
  use_cli = true
  use_msi = false
}

# Spoke (作成した / 既存のサブスクリプション) 用
# Step A (subscription 未確定時) は -target で azapi_resource.* のみを apply し、
# この provider が実際のリソース作成に使われないようにします。
provider "azurerm" {
  alias           = "spoke"
  features        {}
  subscription_id = var.spoke_subscription_id
  tenant_id       = var.spoke_tenant_id
}

# Hub サブスクリプション（既存）
provider "azurerm" {
  alias           = "hub"
  features        {}
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id
}

#############################################
# ========== Step0: Subscription (AzAPI) ==========
#############################################

locals {
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"
}

resource "azapi_resource" "subscription" {
  count     = var.create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name
  parent_id = "/"
  body = jsonencode({
    properties = {
      displayName  = var.subscription_display_name
      billingScope = local.billing_scope
      workload     = var.subscription_workload
    }
  })
  timeouts {
    create = "30m"
    read   = "5m"
    delete = "30m"
  }
}

data "azapi_resource" "subscription_get" {
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name
  parent_id = "/"
  response_export_values = ["properties.subscriptionId"]
  depends_on = [azapi_resource.subscription]
}

#############################################
# ========== Step1: Resource Group ==========
#############################################
# NOTE:
#   - Step0 後に terraform output -raw subscription_id を取得し
#     それを spoke_subscription_id に渡して再 apply してください。
#   - 既存サブスクリプション流用時 (create_subscription=false) は
#     最初から spoke_subscription_id を指定し一括 apply が可能。

resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = var.rg_name
  location = var.location

  # create_subscription=true でまだ subscription_id 未注入の初回 run を避けるための保険:
  # （実際の運用では Step0 のみ -target 指定 ⇒ ここは未評価になるので通常不要）
  lifecycle {
    prevent_destroy = false
  }
}

#############################################
# ========== Step2: Virtual Network (IPAM) ==========
#############################################

resource "azurerm_virtual_network" "vnet" {
  provider            = azurerm.spoke
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # IPAM 自動割当
  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

#############################################
# ========== Step3: Subnet + NSG + Association (IPAM) ==========
#############################################

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

  # IPAM 自動割当
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

#############################################
# ========== Step4a: Peering Hub -> Spoke ==========
#############################################
# Hub 側で作成するピア（allow_gateway_transit=true / use_remote_gateways=false）

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "hub-to-spoke"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${coalesce(var.spoke_subscription_id, data.azapi_resource.subscription_get.output.properties.subscriptionId)}/resourceGroups/${var.rg_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network.vnet]
}

#############################################
# ========== Step4b: Peering Spoke -> Hub ==========
#############################################
# Spoke 側で作成するピア（use_remote_gateways=true）

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

#############################################
# Outputs
#############################################

output "subscription_id" {
  description = "Created or existing subscriptionId (from alias)"
  value       = try(data.azapi_resource.subscription_get.output.properties.subscriptionId, null)
}

output "alias_name" {
  value = var.subscription_alias_name
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "spoke_rg_name" {
  value = azurerm_resource_group.rg.name
}

output "subnet_id" {
  value = azurerm_subnet.subnet.id
}

output "hub_to_spoke_peering_id" {
  value = azurerm_virtual_network_peering.hub_to_spoke.id
}

output "spoke_to_hub_peering_id" {
  value = azurerm_virtual_network_peering.spoke_to_hub.id
}
