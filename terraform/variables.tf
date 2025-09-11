#############################################
# Subscription (Stage0 相当)
#############################################
# 命名規約用 変数（<識別子>-<PJ>-<用途>-<環境>-<リージョン略>-<通番>）
variable "project_name" {
  description = "PJ/案件名（例: bft2）"
  type        = string

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name は必須です。例: bft2"
  }
}

variable "purpose_name" {
  description = "用途（例: kensho2 / 検証 など）"
  type        = string
  default     = ""
  validation {
    condition     = true
    error_message = ""
  }
}

variable "environment_id" {
  description = "環境識別子（例: dev/stg/prd）"
  type        = string
}

variable "region_code" {
  description = "リージョン略号（例: jpe, cac, usw）"
  type        = string
}

variable "sequence" {
  description = "識別番号（例: 001, 002）"
  type        = string
}

variable "create_subscription" {
  description = "サブスクリプションを新規作成するかどうか"
  type        = bool
  default     = false
}

variable "spoke_subscription_id" {
  description = "Spoke サブスクリプション ID（既存利用の場合）"
  type        = string
  default     = ""
}

variable "spoke_tenant_id" {
  description = "Spoke テナント ID（既存利用の場合）"
  type        = string
  default     = ""
}

variable "hub_subscription_id" {
  description = "Hub サブスクリプション ID"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub テナント ID"
  type        = string
  default     = ""
}

variable "management_group_id" {
  description = "管理グループ ID"
  type        = string
  default     = ""
}

variable "billing_account_name" {
  description = "Billing Account Name"
  type        = string
  default     = ""
}

variable "billing_profile_name" {
  description = "Billing Profile Name"
  type        = string
  default     = ""
}

variable "invoice_section_name" {
  description = "Invoice Section Name"
  type        = string
  default     = ""
}

variable "subscription_alias_name" {
  description = "Subscription Alias Name"
  type        = string
  default     = ""
}

variable "subscription_display_name" {
  description = "Subscription Display Name"
  type        = string
  default     = ""
}

variable "subscription_workload" {
  description = "Subscription workload type (Production / DevTest)"
  type        = string
  default     = "Production"
}

# 新規追加
variable "vnet_type" {
  description = "VNet type: public or private"
  type        = string
  default     = ""
}
