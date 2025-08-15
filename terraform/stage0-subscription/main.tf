#############################################
# Stage0: Create Subscription (AzAPI)
# path: terraform/stage0-subscription/main.tf
#############################################

terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "azurerm" {
  features {}
}

# ===== Inputs（値はパイプラインから -var で渡す）=====
variable "subscription_alias_name"   { type = string }
variable "subscription_display_name" { type = string }
variable "billing_account_name"      { type = string }  # 例: 0ae8..._2019-05-31
variable "billing_profile_name"      { type = string }  # 例: IAMZ-4Q5A-BG7-PGB
variable "invoice_section_name"      { type = string }  # 例: 6HB2-O3GL-PJA-PGB
variable "subscription_workload"     { type = string  default = "Production" } # or "DevTest"
variable "management_group_id"       { type = string }  # 例: 2b72ff53-757a-41b9-aa8f-7056292c626e

# ===== Optional: Billing 読取チェック（権限が無ければ明示的に失敗）=====
data "azapi_resource_list" "billing_accounts" {
  type                   = "Microsoft.Billing/billingAccounts@2020-05-01"
  parent_id              = "/"
  response_export_values = ["name"]
}

resource "null_resource" "check_billing_permission" {
  count = length(data.azapi_resource_list.billing_accounts.output) > 0 ? 0 : 1
  provisioner "local-exec" {
    command = "echo '❌ Billing Account にアクセスできません（権限不足）。Billing側の権限を確認してください。' && exit 1"
  }
}

# ===== Build billingScope =====
locals {
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"
}

# ===== Create Subscription (Alias API) =====
resource "azapi_resource" "subscription" {
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name
  parent_id = "/"

  body = jsonencode({
    properties = {
      displayName  = var.subscription_display_name
      billingScope = local.billing_scope
      workload     = var.subscription_workload   # "Production" | "DevTest"
    }
  })

  timeouts {
    create = "30m"
    read   = "5m"
    delete = "30m"
  }

  depends_on = [null_resource.check_billing_permission]
}

# ===== Attach created Subscription to Management Group =====
# API: PUT /providers/Microsoft.Management/managementGroups/{mgId}/subscriptions/{subscriptionId}?api-version=2020-05-01
resource "azapi_resource" "attach_to_mg" {
  type      = "Microsoft.Management/managementGroups/subscriptions@2020-05-01"
  name      = "${var.management_group_id}/subscriptions/${azapi_resource.subscription.output.properties.subscriptionId}"
  parent_id = "/providers/Microsoft.Management/managementGroups"
  body      = jsonencode({})  # Body不要のエンドポイント
  depends_on = [azapi_resource.subscription]
}

# ===== Outputs =====
output "subscription_id" {
  description = "Created subscriptionId"
  value       = try(azapi_resource.subscription.output.properties.subscriptionId, null)
}

output "alias_name" {
  value = var.subscription_alias_name
}

output "display_name" {
  value = var.subscription_display_name
}

output "billing_scope" {
  value = local.billing_scope
}
