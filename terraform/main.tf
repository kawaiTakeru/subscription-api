#############################################
# main.tf（命名規約: <識別子>-<PJ>-<用途>-<環境>-<region_code>-<通番>）
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
  # Subscription creation flow
  need_create_subscription        = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )

  # 命名: 入力正規化（前後空白除去）
  project_raw = trimspace(var.project_name)
  purpose_raw = trimspace(var.purpose_name)

  # スラッグ化（regex を使わない単純置換 + 小文字化）
  project_slug_base = lower(replace(replace(replace(replace(replace(local.project_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))
  purpose_slug_base = lower(replace(replace(replace(replace(replace(local.purpose_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))

  # フォールバック（日本語などで空になった場合）
  project_slug = local.project_slug_base
  purpose_slug = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_base
  )

  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  # 既存リソース名
  name_rg                 = local.base != "" ? "rg-${local.base}" : null
  name_vnet               = local.base != "" ? "vnet-${local.base}" : null
  name_subnet             = local.base != "" ? "snet-${local.base}" : null
  name_nsg                = local.base != "" ? "nsg-${local.base}" : null
  name_sr_allow           = local.base != "" ? "sr-${local.base}-001" : null
  name_sr_deny_internet_in = local.base != "" ? "sr-${local.base}-002" : null
  name_vnetpeer_hub2spoke  = local.base != "" ? "vnetpeerhub2spoke-${local.base}" : null
  name_vnetpeer_spoke2hub  = local.base != "" ? "vnetpeerspoke2hub-${local.base}" : null

  # Bastion 用 NSG 名（ご指定の命名規則）
  # nsg-<PJ/案件名>-<vnettype>-bastion-<環境識別子>-<リージョン略号>-<識別番号>
  name_bastion_nsg = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # Billing Scope（MCA: /providers/Microsoft.Billing/...）
  billing_scope = (
    var.billing_account_name != "" &&
    var.billing_profile_name != "" &&
    var.invoice_section_name != ""
  ) ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}" : null

  # Subscription Alias properties
  sub_properties_base = {
    displayName  = var.subscription_display_name != "" ? var.subscription_display_name : (local.base != "" ? "sub-${local.base}" : "")
    workload     = var.subscription_workload
    billingScope = local.billing_scope
  }
  sub_properties_extra = var.management_group_id != "" ? {
    additionalProperties = { managementGroupId = var.management_group_id }
  } : {}
  sub_properties = merge(local.sub_properties_base, local.sub_properties_extra)

  # Bastion NSG ルール生成用
  is_public = lower(var.vnet_type) == "public"

  # 受信 443 の許可元（public=Internet / private=指定レンジに既存の vpn_client_pool_cidr を流用）
  bastion_https_source = local.is_public ? "Internet" : var.vpn_client_pool_cidr

  # Bastion 向けカスタムルール一覧（画像仕様に基づく）
  bastion_nsg_rules = concat(
    [
      {
        name   = "AllowHttpsInbound"
        prio   = 100
        dir    = "Inbound"
        acc    = "Allow"
        proto  = "Tcp"
        src    = local.bastion_https_source
        dst    = "*"
        dports = ["443"]
      }
    ],
    local.is_public ? [
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

# 既存 NSG（業務用）
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

# Bastion 専用 NSG（新規）
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
