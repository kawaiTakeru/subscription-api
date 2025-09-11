terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azapi  = { source = "azure/azapi",    version = "~> 1.15" }
    azurerm= { source = "hashicorp/azurerm", version = "~> 4.41" }
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
  # === 命名用正規化 ===
  project_raw = trimspace(var.project_name)
  purpose_raw = trimspace(var.purpose_name)

  project_slug_base = lower(replace(replace(replace(replace(replace(local.project_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))
  purpose_slug_base = lower(replace(replace(replace(replace(replace(local.purpose_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))

  project_slug = local.project_slug_base
  purpose_slug = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_base
  )

  # base は従来通り
  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  # Subnet の <用途> 部だけ vnet_type を使用
  name_rg     = local.base != "" ? "rg-${local.base}"   : null
  name_vnet   = local.base != "" ? "vnet-${local.base}" : null
  name_subnet = local.project_slug != "" ? "snet-${local.project_slug}-${var.vnet_type}-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  name_nsg                 = local.base != "" ? "nsg-${local.base}" : null
  name_sr_allow            = local.base != "" ? "sr-${local.base}-001" : null
  name_sr_deny_internet_in = local.base != "" ? "sr-${local.base}-002" : null

  name_vnetpeer_hub2spoke = local.project_slug != "" ? "perr-${local.project_slug}-hubtospoke-${var.environment_id}-${var.sequence}" : null
  name_vnetpeer_spoke2hub = local.project_slug != "" ? "perr-${local.project_slug}-spoketohub-${var.environment_id}-${var.sequence}" : null

  name_sub_alias   = var.subscription_alias_name   != "" ? var.subscription_alias_name   : (local.base != "" ? "sub-${local.base}" : "")
  name_sub_display = var.subscription_display_name != "" ? var.subscription_display_name : (local.base != "" ? "sub-${local.base}" : "")

  billing_scope = (
    var.billing_account_name != "" &&
    var.billing_profile_name != "" &&
    var.invoice_section_name != ""
  ) ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}" : null

  sub_properties_base = {
    displayName  = local.name_sub_display
    workload     = var.subscription_workload
    billingScope = local.billing_scope
  }
  sub_properties_extra = var.management_group_id != "" ? {
    additionalProperties = { managementGroupId = var.management_group_id }
  } : {}
  sub_properties = merge(local.sub_properties_base, local.sub_properties_extra)
}

resource "azapi_resource" "subscription" {
  count     = var.create_subscription && var.spoke_subscription_id == "" ? 1 : 0
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = local.name_sub_alias
  parent_id = "/"
  body      = jsonencode({ properties = local.sub_properties })

  lifecycle {
    precondition {
      condition     = (var.create_subscription && var.spoke_subscription_id == "") ? local.billing_scope != null : true
      error_message = "create_subscription=true の場合、billing_account_name / billing_profile_name / invoice_section_name を設定してください（billingScope 必須）。"
    }
  }
}
