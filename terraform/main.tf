terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
  }
}

provider "azapi" {
  use_cli = true
  use_msi = false
}

variable "subscription_alias_name"   { type = string }
variable "subscription_display_name" { type = string }
variable "billing_account_name"      { type = string }
variable "billing_profile_name"      { type = string }
variable "invoice_section_name"      { type = string }
variable "subscription_workload"     { type = string  default = "Production" }

locals {
  billing_scope = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"
}

resource "azapi_resource" "subscription" {
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

output "subscription_id" {
  value = try(data.azapi_resource.subscription_get.output.properties.subscriptionId, null)
}
