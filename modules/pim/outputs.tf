output "owner_policy_id" {
  value = azurerm_role_management_policy.owner_role_rules.id
}
output "contributor_policy_id" {
  value = azurerm_role_management_policy.contributor_role_rules.id
}
