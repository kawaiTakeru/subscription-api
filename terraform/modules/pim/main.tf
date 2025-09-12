# Data sources for role definitions
data "azurerm_role_definition" "owner" {
  name  = "Owner"
  scope = "/subscriptions/${var.subscription_id}"
}

data "azurerm_role_definition" "contributor" {
  name  = "Contributor"
  scope = "/subscriptions/${var.subscription_id}"
}

# PIM Policy for Owner role
resource "azurerm_role_management_policy" "owner_role_rules" {
  scope              = "/subscriptions/${var.subscription_id}"
  role_definition_id = data.azurerm_role_definition.owner.id

  activation_rules {
    maximum_duration                 = var.maximum_duration
    require_approval                = var.require_approval_for_owner
    require_multifactor_authentication = true
    require_justification           = true
    
    dynamic "approval_stage" {
      for_each = var.require_approval_for_owner && length(var.approvers) > 0 ? [1] : []
      content {
        primary_approver {
          object_id = var.approvers[0]
          type      = "user"
        }
      }
    }
  }

  notification_rules {
    eligible_assignments {
      assignee_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
      admin_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
    }
    active_assignments {
      assignee_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
      admin_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
    }
  }
}

# PIM Policy for Contributor role
resource "azurerm_role_management_policy" "contributor_role_rules" {
  scope              = "/subscriptions/${var.subscription_id}"
  role_definition_id = data.azurerm_role_definition.contributor.id

  activation_rules {
    maximum_duration                 = var.maximum_duration
    require_approval                = var.require_approval_for_contributor
    require_multifactor_authentication = true
    require_justification           = true
    
    dynamic "approval_stage" {
      for_each = var.require_approval_for_contributor && length(var.approvers) > 0 ? [1] : []
      content {
        primary_approver {
          object_id = var.approvers[0]
          type      = "user"
        }
      }
    }
  }

  notification_rules {
    eligible_assignments {
      assignee_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
      admin_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
    }
    active_assignments {
      assignee_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
      admin_notifications {
        default_recipients    = true
        additional_recipients = var.notification_recipients
        notification_level    = "All"
      }
    }
  }
}