variable "subscription_alias_name" {
  description = "内部で使われるサブスクリプションエイリアス名（例: cr_subscription_test_99）"
  type        = string
}

variable "subscription_display_name" {
  description = "ポータルなどで表示される名前"
  type        = string
}

variable "billing_account_name" {
  description = "課金アカウント名（例: abcd1234）"
  type        = string
}

variable "billing_profile_name" {
  description = "課金プロファイル名"
  type        = string
}

variable "invoice_section_name" {
  description = "請求セクション名"
  type        = string
}

variable "subscription_workload" {
  description = "ワークロード種別（例: Production / DevTest）"
  type        = string
  default     = "Production"
}

# 任意の Billing 読み取りチェックを有効化するか（既定: 無効）
variable "enable_billing_check" {
  description = "true にすると Billing Account の読み取り可否を事前にチェック（権限が無いと plan で失敗）"
  type        = bool
  default     = false
}
