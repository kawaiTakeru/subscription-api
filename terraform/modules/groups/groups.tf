# ===========================================================
# 変数定義
# ===========================================================
variable "spoke_subscription_id" { type = string }
variable "spoke_tenant_id"       { type = string }

variable "environment_id" {
  description = "環境識別子（例: prd, stg, dev）"
  type        = string
}

variable "project_slug" {
  description = "プロジェクト名のスラッグ（小文字・記号正規化後）"
  type        = string
}


variable "subscription_owner_emails" {
  description = "UPNまたはメール。所有者権限を与えるユーザの配列"
  type        = list(string)
  default     = []
}

# ===========================================================
# providers
# ===========================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
      configuration_aliases = [ azurerm ]
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
      configuration_aliases = [ azuread ]
    }
  }
}

# ===========================================================
# locals
# ===========================================================
locals {
  group_name_admin     = "azure-${var.project_slug}-${var.environment_id}-group-admin"
  group_name_developer = "azure-${var.project_slug}-${var.environment_id}-group-developer"
  group_name_operator  = "azure-${var.project_slug}-${var.environment_id}-group-operator"

  # 入力された UPN/メール配列をサニタイズ（完全一致のメール形式のみ許可）
  # 受け取りの異常値（ファイル名断片など）を除外し、代表的なドメイン終端のみ許可
  owner_upns_valid = distinct([
    for s in var.subscription_owner_emails : lower(trim(s))
    # 1) 形式: local@domain
    if can(regex("^[^\s\"',;]+@[^\s\"',;]+$", trim(s)))
    # 2) 末尾が .yml / .yaml 等の不正混入を除外
    && !can(regex("\.(yml|yaml)$", lower(trim(s))))
    # 3) 許可するドメイン終端（onmicrosoft.com または代表的TLD）
  && (can(regex("@[^@]+\.onmicrosoft\.com$", lower(trim(s))))
    || can(regex("@[^@]+\.(com|net|org|biz|info|io|jp|co\.jp|ne\.jp|co|ai)$", lower(trim(s)))))
  ])
}

# -----------------------------------------------------------
# AAD グループ作成
# -----------------------------------------------------------
resource "azuread_group" "admin" {
  display_name     = local.group_name_admin
  security_enabled = true
}
resource "azuread_group" "developer" {
  display_name     = local.group_name_developer
  security_enabled = true
}
resource "azuread_group" "operator" {
  display_name     = local.group_name_operator
  security_enabled = true
}

# -----------------------------------------------------------
# 所有者メール → ユーザ解決
# -----------------------------------------------------------
data "azuread_user" "owners" {
  for_each            = toset(local.owner_upns_valid)
  user_principal_name = each.value
}

# -----------------------------------------------------------
# サブスクリプション Owner ロールを所有者グループに割当
# -----------------------------------------------------------
data "azurerm_subscription" "spoke" {}

data "azurerm_role_definition" "owner" {
  name = "Owner"
}

resource "azurerm_role_assignment" "rg_owner_admin" {
  scope              = data.azurerm_subscription.spoke.id
  role_definition_id = data.azurerm_role_definition.owner.role_definition_id
  principal_id       = azuread_group.admin.id
}

# -----------------------------------------------------------
# 所有者ユーザを Admin グループに所属させる
# -----------------------------------------------------------
resource "azuread_group_member" "admin_members" {
  for_each         = data.azuread_user.owners
  group_object_id  = azuread_group.admin.id
  member_object_id = each.value.object_id
}

# -----------------------------------------------------------
# Outputs（デバッグ・確認用）
# -----------------------------------------------------------
output "group_admin_object_id"     { value = azuread_group.admin.id }
output "group_developer_object_id" { value = azuread_group.developer.id }
output "group_operator_object_id"  { value = azuread_group.operator.id }
