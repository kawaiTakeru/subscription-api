#############################################
# Combined Terraform Root (Stages 0~4b)
# 改訂ポイント:
#  - need_create_subscription = create_subscription && spoke_subscription_id=="" に変更
#  - data.azapi_resource.subscription_get も同じ条件で count
#  - effective_spoke_subscription_id をローカルで集約
#  - Peering の remote_virtual_network_id は local.effective_spoke_subscription_id を使用
#  - 既存利用 (spoke_subscription_id 指定 / create=false) 時は alias リソース未作成
#  - 新規作成後 pipeline から TF_VAR_spoke_subscription_id を注入すると
#    次回以降 need_create_subscription=false となり再作成を抑制 (subscription を継続管理したい場合は
#    pipeline 側で overrideCreateSubscription=true を維持するか、設計に応じて調整)
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

provider "azapi" {
  use_cli = true
  use_msi = false
}

# Spoke Provider:
# spoke_subscription_id 未確定時は subscription_id を省略し CLI 既定 (service connection) に委譲。
# Step0 では -target で azapi_resource.subscription[...] のみ apply するため spoke 側リソースは未評価。
provider "azurerm" {
  alias    = "spoke"
  features {}
  # var.spoke_subscription_id が空なら省略 (CLI の current subscription)
  # NOTE: 空 GUID を入れると失敗するため条件分岐。
  subscription_id = var.spoke_subscription_id != "" ? var.spoke_subscription_id : null
  tenant_id       = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  alias           = "hub"
  features        {}
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

#############################################
# Locals
#############################################

locals {
  billing_scope                = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"
  need_create_subscription     = var.create_subscription && var.spoke_subscription_id == ""
  # subscription_get[0] が存在する時にのみ値を参照
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )
}

#############################################
# Step0: Subscription (conditional)
#############################################

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
    }
  })
  timeouts {
    create = "30m"
    read   = "5m"
    delete = "30m"
  }
  lifecycle {
    # 誤消し防止。必要に応じて true にする。
    prevent_destroy = false
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

#############################################
# Step1: Resource Group
#############################################

resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = var.rg_name
  location = var.location
  lifecycle {
    prevent_destroy = false
  }
}

#############################################
# Step2: Virtual Network (IPAM)
#############################################

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

#############################################
# Step3: Subnet + NSG + Association
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
# Step4a: Peering Hub -> Spoke
#############################################

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "hub-to-spoke"
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${local.effective_spoke_subscription_id}/resourceGroups/${var.rg_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false

  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

#############################################
# Step4b: Peering Spoke -> Hub
#############################################

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
  description = "Effective subscriptionId (new or existing)"
  value       = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null
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
