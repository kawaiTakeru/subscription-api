# ...（前略）

locals {
  # Billing scope
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"

  # Subscription creation flow
  need_create_subscription        = var.create_subscription && var.spoke_subscription_id == ""
  effective_spoke_subscription_id = coalesce(
    var.spoke_subscription_id,
    try(data.azapi_resource.subscription_get[0].output.properties.subscriptionId, "")
  )

  # 命名: スラッグ化（regexreplace + trimspace）
  project_raw  = trimspace(var.project_name)
  purpose_raw  = trimspace(var.purpose_name)

  # 英数字のみを残す（日本語「検証」は特例で kensho に）
  project_slug         = lower(regexreplace(local.project_raw, "[^0-9A-Za-z]", ""))
  purpose_slug_initial = lower(regexreplace(local.purpose_raw, "[^0-9A-Za-z]", ""))
  purpose_slug         = length(local.purpose_slug_initial) > 0 ? local.purpose_slug_initial : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_initial
  )

  base_parts = [for p in [local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence] : p if length(p) > 0]
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

# ...（後略）
