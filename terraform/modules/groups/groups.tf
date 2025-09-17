terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

# 入力
variable "spoke_subscription_id" { type = string }
variable "spoke_tenant_id"       { type = string }

variable "group_name_admin"     { type = string }
variable "group_name_developer" { type = string }
variable "group_name_operator"  { type = string }

variable "subscription_owner_emails" {
  description = "UPNまたはメール。所有者権限を与えるユーザの配列"
  type        = list(string)
  default     = []
}

# AAD グループ作成（Step1 相当）
resource "azuread_group" "admin" {
  display_name     = var.group_name_admin
  security_enabled = true
}
resource "azuread_group" "developer" {
  display_name     = var.group_name_developer
  security_enabled = true
}
resource "azuread_group" "operator" {
  display_name     = var.group_name_operator
  security_enabled = true
}

# 所有者メール → ユーザ解決
data "azuread_user" "owners" {
  for_each            = toset(var.subscription_owner_emails)
  user_principal_name = each.value
}

# サブスクリプション Owner ロールを所有者グループに割当（Step2 の一部）
data "azurerm_subscription" "spoke" {}

data "azurerm_role_definition" "owner" {
  name = "Owner"
}

resource "azurerm_role_assignment" "rg_owner_admin" {
  scope              = data.azurerm_subscription.spoke.id
  role_definition_id = data.azurerm_role_definition.owner.role_definition_id
  principal_id       = azuread_group.admin.id
}

# 所有者ユーザを Admin グループに所属させる
resource "azuread_group_member" "admin_members" {
  for_each         = data.azuread_user.owners
  group_object_id  = azuread_group.admin.id
  member_object_id = each.value.object_id
}

# 出力
output "group_admin_object_id"     { value = azuread_group.admin.id }
output "group_developer_object_id" { value = azuread_group.developer.id }
output "group_operator_object_id"  { value = azuread_group.operator.id }
