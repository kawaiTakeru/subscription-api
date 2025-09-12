#============================================================================
# サブスクリプション ロールのPIM設定.

# 対象サブスクリプション.
data "azurerm_subscription" "subs" {
  subscription_id = var.subscription_id
}

#============================================================================
# サブスクリプション-所有者ロール.
data "azurerm_role_definition" "subs_owner" {
  name = "Owner"
  scope = data.azurerm_subscription.subs.id
}

# サブスクリプション-所有者ロール-PIM設定.
resource "azurerm_role_management_policy" "owner_role_rules" {
  # 対象のAzureリソース.
  scope = data.azurerm_subscription.subs.id
  # 対象のロール.
  role_definition_id = data.azurerm_role_definition.subs_owner.id

  # アクティブ化.
  activation_rules {
    # アクティブ化の最大期間("PT30M","PT1H","PT1H30M"～"PT1D"までの30分刻み).
    maximum_duration = "PT2H"
    # アクティブ化で必要: Azure MFA (true = Azure MFA, false = なし)
    # ※ required_conditional_access_authentication_context と同時に指定できない。
    require_multifactor_authentication = false
    # アクティブ化で必要: Microsoft Entra 条件付きアクセス認証コンテキスト.
    # ※ require_multifactor_authentication と同時に指定できない。
    required_conditional_access_authentication_context = null # "[Conditional Access context]"
    # アクティブ化に理由が必要(true, false)
    require_justification = true
    # アクティブ化の時にチケット情報を要求します(true, false)
    require_ticket_info = false
    # アクティブにするには承認が必要です.
    require_approval = true
    # 承認者設定
    approval_stage {
      # 承認者(配列値に従ってprimary_approverを複数適用する)
      dynamic "primary_approver" {
        for_each = var.approvers
        content {
          # 承認者の種類("User", "Group")
          type = primary_approver.value.type
          # 承認者のオブジェクトID.
          object_id = primary_approver.value.object_id
        }
      }
      # 承認者(複数人の場合はprimary_approverを複数記載する)
      # primary_approver {
      #   # 承認者の種類("User", "Group")
      #   type = "User"
      #   # 承認者のオブジェクトID.
      #   object_id = "00000000-0000-0000-0000-000000000000"
      # }
    }
  }

  # 割り当て(資格のある割り当て)
  eligible_assignment_rules {
    # 永続的に資格のある割り当てを許可する(false = 永続的)
    expiration_required = false
    # 次の後に、資格のある割り当ての有効期限が切れる:
    # ("P15D", "P30D", "P90D", "P180D", "P365D")
    expire_after = "P15D"
  }

  # 割り当て(アクティブな割り当て)
  active_assignment_rules {
    # 永続するアクティブな割り当てを許可する(false = 永続的)
    expiration_required = true
    # 次の後に、資格のある割り当ての有効期限が切れる:
    # ("P15D", "P30D", "P90D", "P180D", "P365D")
    expire_after = "P15D"
    # アクティブな割り当てに Azure Multi-Factor Authentication を必要とする.
    require_multifactor_authentication = true
    # アクティブな割り当てに理由が必要
    require_justification = true
  }

  # 通知.
  notification_rules {
    # このロールにメンバーが資格のあるメンバーとして割り当てられたときに通知を送信する:
    eligible_assignments {
      # ロールの割り当てのアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロール割り当て済みユーザー (担当者) への通知.
      assignee_notifications {
        # 既定の受信者: true = 担当者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロールの割り当ての更新または延長の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }

    # このロールにメンバーがアクティブとして割り当てられたときに通知を送信する:
    active_assignments {
      # ロールの割り当てのアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = true
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロール割り当て済みユーザー (担当者) への通知.
      assignee_notifications {
        # 既定の受信者: true = 担当者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロールの割り当ての更新または延長の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }

    # 資格のあるメンバーがこのロールをアクティブ化したときに通知を送信する:
    eligible_activations {
      # ロールのアクティブ化のアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # アクティブ化されたユーザー (要求元) への通知.
      assignee_notifications {
        # 既定の受信者: true = 要求元.
        default_recipients = true
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # アクティブ化の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = true
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }
  }
}

#============================================================================
# サブスクリプション-共同作成者ロール.
data "azurerm_role_definition" "subs_contributor" {
  name = "Contributor"
  scope = data.azurerm_subscription.subs.id
}

# サブスクリプション-所有者ロール-PIM設定.
resource "azurerm_role_management_policy" "contributor_role_rules" {
  # 対象のAzureリソース.
  scope = data.azurerm_subscription.subs.id
  # 対象のロール.
  role_definition_id = data.azurerm_role_definition.subs_contributor.id

  # アクティブ化.
  activation_rules {
    # アクティブ化の最大期間("PT30M","PT1H","PT1H30M"～"PT1D"までの30分刻み).
    maximum_duration = "PT8H"
    # アクティブ化で必要: Azure MFA (true = Azure MFA, false = なし)
    # ※ required_conditional_access_authentication_context と同時に指定できない。
    require_multifactor_authentication = false
    # アクティブ化で必要: Microsoft Entra 条件付きアクセス認証コンテキスト.
    # ※ require_multifactor_authentication と同時に指定できない。
    required_conditional_access_authentication_context = null # "[Conditional Access context]"
    # アクティブ化に理由が必要(true, false)
    require_justification = true
    # アクティブ化の時にチケット情報を要求します(true, false)
    require_ticket_info = false
    # アクティブにするには承認が必要です.
    require_approval = true
    # 承認者設定
    approval_stage {
      # 承認者(配列値に従ってprimary_approverを複数適用する)
      dynamic "primary_approver" {
        for_each = var.approvers
        content {
          # 承認者の種類("User", "Group")
          type = primary_approver.value.type
          # 承認者のオブジェクトID.
          object_id = primary_approver.value.object_id
        }
      }
      # 承認者(複数人の場合はprimary_approverを複数記載する)
      # primary_approver {
      #   # 承認者の種類("User", "Group")
      #   type = "User"
      #   # 承認者のオブジェクトID.
      #   object_id = "00000000-0000-0000-0000-000000000000"
      # }
    }
  }

  # 割り当て(資格のある割り当て)
  eligible_assignment_rules {
    # 永続的に資格のある割り当てを許可する(false = 永続的)
    expiration_required = false
    # 次の後に、資格のある割り当ての有効期限が切れる:
    # ("P15D", "P30D", "P90D", "P180D", "P365D")
    expire_after = "P15D"
  }

  # 割り当て(アクティブな割り当て)
  active_assignment_rules {
    # 永続するアクティブな割り当てを許可する(false = 永続的)
    expiration_required = true
    # 次の後に、資格のある割り当ての有効期限が切れる:
    # ("P15D", "P30D", "P90D", "P180D", "P365D")
    expire_after = "P15D"
    # アクティブな割り当てに Azure Multi-Factor Authentication を必要とする.
    require_multifactor_authentication = true
    # アクティブな割り当てに理由が必要
    require_justification = true
  }

  # 通知.
  notification_rules {
    # このロールにメンバーが資格のあるメンバーとして割り当てられたときに通知を送信する:
    eligible_assignments {
      # ロールの割り当てのアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロール割り当て済みユーザー (担当者) への通知.
      assignee_notifications {
        # 既定の受信者: true = 担当者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロールの割り当ての更新または延長の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }

    # このロールにメンバーがアクティブとして割り当てられたときに通知を送信する:
    active_assignments {
      # ロールの割り当てのアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = true
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロール割り当て済みユーザー (担当者) への通知.
      assignee_notifications {
        # 既定の受信者: true = 担当者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # ロールの割り当ての更新または延長の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }

    # 資格のあるメンバーがこのロールをアクティブ化したときに通知を送信する:
    eligible_activations {
      # ロールのアクティブ化のアラート.
      admin_notifications {
        # 既定の受信者: true = 管理者.
        default_recipients = false
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # アクティブ化されたユーザー (要求元) への通知.
      assignee_notifications {
        # 既定の受信者: true = 要求元.
        default_recipients = true
        # その他の受信者.
        additional_recipients = []
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
      # アクティブ化の承認要求.
      approver_notifications {
        # 既定の受信者: true = 承認者.
        default_recipients = true
        # 重要なメールのみ("Critical" = True, "All" = False)
        # ※受信者が全て無効の場合は"All"にしなければならない.
        notification_level = "All"
      }
    }
  }
}

#============================================================================
