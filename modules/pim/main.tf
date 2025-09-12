variable "subscription_id" {
  type        = string
  description = "PIM設定対象のサブスクリプションID"
}

variable "approvers" {
  type = list(object({
    type      = string
    object_id = string
  }))
  description = "承認者(ユーザーまたはグループ)情報リスト(type: \"User\" or \"Group\", object_id: オブジェクトID)"
}
