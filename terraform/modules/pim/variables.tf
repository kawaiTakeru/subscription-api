variable "subscription_id" {
  description = "The subscription ID where PIM policies will be applied"
  type        = string
}

variable "notification_recipients" {
  description = "List of email addresses for PIM notifications"
  type        = list(string)
  default     = []
}

variable "approvers" {
  description = "List of user object IDs for approval process (empty means no approval required)"
  type        = list(string)
  default     = []
}

variable "maximum_duration" {
  description = "Maximum duration for role elevation (ISO 8601 duration format, e.g., PT4H for 4 hours)"
  type        = string
  default     = "PT4H"
}

variable "require_approval_for_owner" {
  description = "Whether to require approval for Owner role elevation"
  type        = bool
  default     = true
}

variable "require_approval_for_contributor" {
  description = "Whether to require approval for Contributor role elevation"
  type        = bool
  default     = false
}