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
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
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
  subscription_id = local.effective_spoke_subscription_id
  tenant_id       = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

# AzureAD プロバイダ（メール→ユーザー解決、PIM承認者解決、管理グループ作成に使用）
provider "azuread" {
  alias     = "spoke"
  tenant_id = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

locals {
  # サブスクリプション新規作成判定（spoke_subscription_id未指定かつcreate_subscription=true）
  need_create_subscription = var.create_subscription && var.spoke_subscription_id == ""

  # 新規作成時は azapi の data/resource から取得、既存流用時はそのまま
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id != "" ? var.spoke_subscription_id : null,
    local.need_create_subscription ? try(jsondecode(data.azapi_resource.subscription_get[0].output).properties.subscriptionId, null) : null,
    local.need_create_subscription ? try(jsondecode(azapi_resource.subscription[0].output).properties.subscriptionId, null) : null
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

  vnet_type = "private"

  name_rg          = local.base != "" ? "rg-${local.base}" : null
  name_vnet        = local.base != "" ? "vnet-${local.base}" : null
  name_subnet      = local.project_slug != "" ? "snet-${local.project_slug}-${lower(local.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_nsg         = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(local.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_nsg = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(local.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  billing_scope = (
    var.billing_account_name != "" &&
    var.billing_profile_name != "" &&
    var.invoice_section_name != ""
  ) ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}" : null
}

# -----------------------------------------------------------
# サブスクリプション新規作成（azapi + alias方式）
# -----------------------------------------------------------
resource "azapi_resource" "subscription" {
  count     = local.need_create_subscription ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name != "" ? var.subscription_alias_name : "alias-${local.base}"
  parent_id = "/"
  body = jsonencode({
    properties = {
      displayName  = var.subscription_display_name != "" ? var.subscription_display_name : "sub-${local.base}"
      billingScope = local.billing_scope
      workload     = var.subscription_workload
      additionalProperties = {
        managementGroupId = var.management_group_id != "" ? var.management_group_id : "/providers/Microsoft.Management/managementGroups/mg-bft-test"
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
  name      = var.subscription_alias_name != "" ? var.subscription_alias_name : "alias-${local.base}"
  parent_id = "/"
  response_export_values = ["properties.subscriptionId"]
  depends_on = [azapi_resource.subscription]
}

# -----------------------------------------------------------
# 管理用グループ作成
# -----------------------------------------------------------
module "step1_2_groups_roles" {
  source     = "../modules/groups"
  providers  = { azurerm = azurerm.spoke, azuread = azuread.spoke }

  spoke_subscription_id     = var.spoke_subscription_id
  spoke_tenant_id           = var.spoke_tenant_id
  group_name_admin          = "azure-${local.project_slug}-${local.purpose_slug}-${var.environment_id}-group-admin"
  group_name_developer      = "azure-${local.project_slug}-${local.purpose_slug}-${var.environment_id}-group-developer"
  group_name_operator       = "azure-${local.project_slug}-${local.purpose_slug}-${var.environment_id}-group-operator"
  subscription_owner_emails = var.subscription_owner_emails
}

# -----------------------------------------------------------
# Resource Group
# -----------------------------------------------------------
module "step4_resource_group" {
  source                = "../modules/Resource Group"
  providers             = { azurerm = azurerm.spoke }
  spoke_tenant_id       = var.spoke_tenant_id
  spoke_subscription_id = var.spoke_subscription_id
  name_rg               = local.name_rg
  region                = var.region
}

# -----------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------
module "step5_vnet" {
  source                = "../modules/VNet"
  providers             = { azurerm = azurerm.spoke }
  spoke_subscription_id = var.spoke_subscription_id
  spoke_tenant_id       = var.spoke_tenant_id
  name_vnet             = local.name_vnet
  region                = module.step4_resource_group.rg_location
  rg_name               = module.step4_resource_group.rg_name
  ipam_pool_id          = var.ipam_pool_id
  vnet_number_of_ips    = var.vnet_number_of_ips
}

# -----------------------------------------------------------
# NSG（業務用/サブネット用）/ Bastion用NSG / Subnet（業務用・Bastion）/ NSGアソシエーション
# -----------------------------------------------------------
module "step6_networking" {
  source                       = "../modules/Subnet+NSG+Association.tf"
  providers                    = { azurerm = azurerm.spoke }
  spoke_tenant_id              = var.spoke_tenant_id
  spoke_subscription_id        = var.spoke_subscription_id
  rg_name                      = module.step4_resource_group.rg_name
  region                       = module.step4_resource_group.rg_location
  vnet_name                    = module.step5_vnet.vnet_name
  name_subnet                  = local.name_subnet
  name_nsg                     = local.name_nsg
  name_bastion_nsg             = local.name_bastion_nsg
  vnet_type                    = local.vnet_type
  ipam_pool_id                 = var.ipam_pool_id
  subnet_number_of_ips         = var.subnet_number_of_ips
  bastion_subnet_number_of_ips = var.bastion_subnet_number_of_ips
}

# -----------------------------------------------------------
# Bastion Host
# -----------------------------------------------------------
module "bastion" {
  source = "../modules/bastion"
  providers = { azurerm = azurerm.spoke }
  environment_id          = var.environment_id
  region_code             = var.region_code
  sequence                = var.sequence
  vnet_type               = local.vnet_type
  project_slug            = local.project_slug
  resource_group_location = module.step4_resource_group.rg_location
  resource_group_name     = module.step4_resource_group.rg_name
  bastion_subnet_id       = module.step6_networking.bastion_subnet_id
}

# -----------------------------------------------------------
# ルートテーブル・ルート（プライベート環境のみ）
# -----------------------------------------------------------
module "route-table" {
  source = "../modules/route-table"
  providers = {
    azurerm = azurerm.spoke
  }
  environment_id          = var.environment_id
  region_code             = var.region_code
  sequence                = var.sequence
  project_slug            = local.project_slug
  base                    = local.base
  resource_group_location = module.step4_resource_group.rg_location
  resource_group_name     = module.step4_resource_group.rg_name
  subnet_id               = module.step6_networking.subnet_id
}

# -----------------------------------------------------------
# VNet Peering（Hub⇔Spoke）
# -----------------------------------------------------------
module "vnet-peering" {
  source = "../modules/vnet-peering"
  providers = {
    azurerm.spoke = azurerm.spoke
    azurerm.hub   = azurerm.hub
  }
  effective_spoke_subscription_id = local.effective_spoke_subscription_id
  hub_subscription_id             = var.hub_subscription_id
  hub_vnet_name                   = var.hub_vnet_name
  hub_rg_name                     = var.hub_rg_name
  base                            = local.base

  depends_on = [module.step5_vnet]
}

# -----------------------------------------------------------
# PIM設定（Owner / Contributor）- 既存グループのみ使用
# -----------------------------------------------------------
module "pim" {
  count = (length(var.pim_owner_approver_group_names) > 0 && length(var.pim_contributor_approver_group_names) > 0) ? 1 : 0
  source = "../modules/pim"
  providers = {
    azurerm = azurerm.spoke
    azuread = azuread.spoke
  }
  owner_approver_group_names      = var.pim_owner_approver_group_names
  contributor_approver_group_names = var.pim_contributor_approver_group_names
  subscription_id                 = var.spoke_subscription_id
  tenant_id                       = var.spoke_tenant_id
}

# created_subscription_id：既存なら var を、作成なら data/resource を jsondecode して GUID を返す
output "created_subscription_id" {
  description = "Spoke subscription id (newly created or reused)."
  value = coalesce(
    var.spoke_subscription_id != "" ? var.spoke_subscription_id : null,
    local.need_create_subscription ? try(jsondecode(data.azapi_resource.subscription_get[0].output).properties.subscriptionId, null) : null,
    local.need_create_subscription ? try(jsondecode(azapi_resource.subscription[0].output).properties.subscriptionId, null) : null
  )
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "debug_project_name"      { value = var.project_name }
output "debug_purpose_name"      { value = var.purpose_name }
output "debug_project_slug"      { value = local.project_slug }
output "debug_purpose_slug"      { value = local.purpose_slug }
output "debug_base_parts"        { value = local.base_parts }
output "base_naming"             { value = local.base }
output "rg_expected_name"        { value = local.name_rg }
output "vnet_expected_name"      { value = local.name_vnet }
output "subscription_id"         { value = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null }
output "spoke_rg_name"           { value = module.step4_resource_group.rg_name }
output "spoke_vnet_name"         { value = module.step5_vnet.vnet_name }
output "hub_to_spoke_peering_id" { value = module.vnet-peering.hub_to_spoke_peering_id }
output "spoke_to_hub_peering_id" { value = module.vnet-peering.spoke_to_hub_peering_id }
output "bastion_host_id"         { value = module.bastion.bastion_host_id }
output "bastion_public_ip"       { value = module.bastion.bastion_public_ip }

