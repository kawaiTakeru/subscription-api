#############################################
# Stage0: Create Subscription (AzAPI)
# path: terraform/stage0-subscription/main.tf
#############################################

terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azapi = {
      source  = "azure/azapi"   # ← 名前空間は azure（大文字小文字は不問）
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

# ★ 重要: AzAPI に CLI 認証を使わせる（MSI/IMDS を試させない）
provider "azapi" {
  use_cli = true
}

# ===== Optional: Billing 読取チェック =====
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

# ===== Read Back (GET) to ensure subscriptionId is available =====
data "azapi_resource" "subscription_get" {
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = azapi_resource.subscription.name
  parent_id = "/"

  response_export_values = ["properties.subscriptionId"]

  depends_on = [azapi_resource.subscription]
}

# ===== Outputs =====
output "subscription_id" {
  description = "Created subscriptionId"
  value       = try(data.azapi_resource.subscription_get.output.properties.subscriptionId, null)
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
