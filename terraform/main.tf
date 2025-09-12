#############################################
# main.tf
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.44"
    }
  }
}

provider "azapi" {
  use_cli = true
  use_msi = false
}

provider "azurerm" {
  features {}
  alias           = "spoke"
  subscription_id = var.spoke_subscription_id != "" ? var.spoke_subscription_id : null
  tenant_id       = var.spoke_tenant_id != "" ? var.spoke_tenant_id : null
}

provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  tenant_id       = var.hub_tenant_id != "" ? var.hub_tenant_id : null
}

locals {
  # 新規サブスクリプション関連は常にfalse（pipelineで既存を必ず渡す）
  need_create_subscription        = false
  effective_spoke_subscription_id = var.spoke_subscription_id

  project_raw = trimspace(var.project_name)
  purpose_raw = trimspace(var.purpose_name)

  project_slug_base = lower(replace(replace(replace(replace(replace(local.project_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))
  purpose_slug_base = lower(replace(replace(replace(replace(replace(local.purpose_raw, " ", "-"), "_", "-"), ".", "-"), "/", "-"), "\\", "-"))

  project_slug = local.project_slug_base
  purpose_slug = length(local.purpose_slug_base) > 0 ? local.purpose_slug_base : (
    local.purpose_raw == "検証" ? "kensho" : local.purpose_slug_base
  )

  base_parts = compact([local.project_slug, local.purpose_slug, var.environment_id, var.region_code, var.sequence])
  base       = join("-", local.base_parts)

  name_rg                  = local.base != "" ? "rg-${local.base}" : null
  name_vnet                = local.base != "" ? "vnet-${local.base}" : null

  name_subnet              = local.project_slug != "" ? "snet-${local.project_slug}-${lower(var.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_nsg                 = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-${local.purpose_slug}-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  name_sr_allow            = local.base != "" ? "sr-${local.base}-001" : null
  name_sr_deny_internet_in = local.base != "" ? "sr-${local.base}-002" : null
  name_vnetpeer_hub2spoke  = local.base != "" ? "vnetpeerhub2spoke-${local.base}" : null
  name_vnetpeer_spoke2hub  = local.base != "" ? "vnetpeerspoke2hub-${local.base}" : null

  name_bastion_nsg = local.project_slug != "" ? "nsg-${local.project_slug}-${lower(var.vnet_type)}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_host     = local.project_slug != "" ? "bastion-${local.project_slug}-${lower(var.vnet_type)}-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_bastion_public_ip = local.project_slug != "" ? "pip-${local.project_slug}-bastion-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  # NATGW/PIP命名を「ng」に統一
  name_natgw     = local.project_slug != "" ? "ng-${local.project_slug}-nat-${var.environment_id}-${var.region_code}-${var.sequence}" : null
  name_natgw_pip = local.project_slug != "" ? "ng-${local.project_slug}-pip-${var.environment_id}-${var.region_code}-${var.sequence}" : null

  name_route_table = local.base != "" ? "rt-${local.base}" : null
  name_udr_default = local.project_slug != "" ? "udr-${local.project_slug}-er-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms1    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-001" : null
  name_udr_kms2    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-002" : null
  name_udr_kms3    = local.project_slug != "" ? "udr-${local.project_slug}-kmslicense-${var.environment_id}-${var.region_code}-003" : null

  billing_scope = (
    var.billing_account_name != "" &&
    var.billing_profile_name != "" &&
    var.invoice_section_name != ""
  ) ? "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}" : null

  sub_properties_base = {
    displayName  = var.subscription_display_name != "" ? var.subscription_display_name : (local.base != "" ? "sub-${local.base}" : "")
    workload     = var.subscription_workload
    billingScope = local.billing_scope
  }
  sub_properties_extra = var.management_group_id != "" ? {
    additionalProperties = { managementGroupId = var.management_group_id }
  } : {}
  sub_properties = merge(local.sub_properties_base, local.sub_properties_extra)

  is_public  = lower(var.vnet_type) == "public"
  is_private = !local.is_public

  bastion_https_source = local.is_public ? "Internet" : var.vpn_client_pool_cidr

  bastion_nsg_rules = [
    {
      name   = "AllowGatewayManagerInbound"
      prio   = 100
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "GatewayManager"
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowAzureLoadBalancerInbound"
      prio   = 105
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "AzureLoadBalancer"
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowHttpsInbound"
      prio   = 110
      dir    = "Inbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = local.bastion_https_source
      dst    = "*"
      dports = ["443"]
    },
    {
      name   = "AllowSshRdpOutbound"
      prio   = 200
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "*"
      dst    = "VirtualNetwork"
      dports = ["22","3389"]
    },
    {
      name   = "AllowAzureCloudOutbound"
      prio   = 210
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "Tcp"
      src    = "*"
      dst    = "AzureCloud"
      dports = ["443"]
    },
    {
      name   = "AllowBastionCommunicationOutbound"
      prio   = 220
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "VirtualNetwork"
      dst    = "VirtualNetwork"
      dports = ["8080","5701"]
    },
    {
      name   = "AllowHttpOutbound"
      prio   = 230
      dir    = "Outbound"
      acc    = "Allow"
      proto  = "*"
      src    = "*"
      dst    = "Internet"
      dports = ["80"]
    }
  ]
}

resource "azurerm_resource_group" "rg" {
  provider = azurerm.spoke
  name     = local.name_rg
  location = var.region
}

resource "azurerm_virtual_network" "vnet" {
  provider            = azurerm.spoke
  name                = local.name_vnet
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.vnet_number_of_ips
  }
}

resource "azurerm_network_security_group" "subnet_nsg" {
  provider            = azurerm.spoke
  name                = local.name_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = local.name_sr_allow
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.allowed_port
    source_address_prefix      = var.vpn_client_pool_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = local.name_sr_deny_internet_in
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "bastion_nsg" {
  provider            = azurerm.spoke
  name                = local.name_bastion_nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = { for r in local.bastion_nsg_rules : r.name => r }
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.prio
      direction                  = security_rule.value.dir
      access                     = security_rule.value.acc
      protocol                   = security_rule.value.proto
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.dports
      source_address_prefix      = security_rule.value.src
      destination_address_prefix = security_rule.value.dst
    }
  }
}

resource "azurerm_subnet" "subnet" {
  provider             = azurerm.spoke
  name                 = local.name_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.subnet_number_of_ips
  }
}

resource "azurerm_subnet" "bastion_subnet" {
  provider             = azurerm.spoke
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.bastion_subnet_number_of_ips
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion_assoc" {
  provider                  = azurerm.spoke
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

resource "azurerm_public_ip" "bastion_pip" {
  provider            = azurerm.spoke
  name                = local.name_bastion_public_ip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_bastion_host" "bastion" {
  provider            = azurerm.spoke
  name                = local.name_bastion_host
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku         = "Standard"
  scale_units = 2

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  copy_paste_enabled     = false
  file_copy_enabled      = false
  ip_connect_enabled     = false
  shareable_link_enabled = false
  tunneling_enabled      = false
}

# ======================
# NAT Gateway（public のみ）
# ======================
resource "azurerm_public_ip" "natgw_pip" {
  count               = local.is_public ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_natgw_pip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_nat_gateway" "natgw" {
  count               = local.is_public ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_natgw
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
  count                = local.is_public ? 1 : 0
  provider             = azurerm.spoke
  nat_gateway_id       = azurerm_nat_gateway.natgw[0].id
  public_ip_address_id = azurerm_public_ip.natgw_pip[0].id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_natgw_assoc" {
  count          = local.is_public ? 1 : 0
  provider       = azurerm.spoke
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw[0].id
}

resource "azurerm_route_table" "route_table_private" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_route_table
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route" "route_default_to_gateway" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_default
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_route" "route_kms1" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms1
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "20.118.99.224/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms2" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms2
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "40.83.235.53/32"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "route_kms3" {
  count               = local.is_private ? 1 : 0
  provider            = azurerm.spoke
  name                = local.name_udr_kms3
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.route_table_private[0].name
  address_prefix      = "23.102.135.246/32"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "subnet_rt_assoc" {
  count          = local.is_private ? 1 : 0
  provider       = azurerm.spoke
  subnet_id      = azurerm_subnet.subnet.id
  route_table_id = azurerm_route_table.route_table_private[0].id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = local.name_vnetpeer_hub2spoke
  resource_group_name       = var.hub_rg_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = "/subscriptions/${local.effective_spoke_subscription_id}/resourceGroups/${local.name_rg}/providers/Microsoft.Network/virtualNetworks/${local.name_vnet}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network.vnet]
}

# Peering Spoke -> Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.spoke
  name                      = local.name_vnetpeer_spoke2hub
  resource_group_name       = local.name_rg
  virtual_network_name      = local.name_vnet
  remote_virtual_network_id = "/subscriptions/${var.hub_subscription_id}/resourceGroups/${var.hub_rg_name}/providers/Microsoft.Network/virtualNetworks/${var.hub_vnet_name}"

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.hub_to_spoke
  ]
}

#########################################################
# Step8: PIM（public/private)
#########################################################

# 承認グループIDを取得
data "azuread_group" "ot_oprt_is_manager" {
  display_name     = "ot-oprt-is-manager"
  security_enabled = true
}
data "azuread_group" "ot_oprt_is_general" {
  display_name     = "ot-oprt-is-general"
  security_enabled = true
}
data "azuread_group" "ot_oprt_is_director" {
  display_name     = "ot-oprt-is-director"
  security_enabled = true
}

# サブスクリプション情報（id取得用）
data "azurerm_subscription" "this" {
  subscription_id = local.effective_spoke_subscription_id
}

# サブスクリプションOwnerロール定義
data "azurerm_role_definition" "subs_owner" {
  name  = "Owner"
  scope = data.azurerm_subscription.this.id
}

# サブスクリプションContributorロール定義
data "azurerm_role_definition" "subs_contributor" {
  name  = "Contributor"
  scope = data.azurerm_subscription.this.id
}

# 承認者リスト
locals {
  pim_approvers = [
    {
      type      = "Group"
      object_id = data.azuread_group.ot_oprt_is_manager.object_id
    },
    {
      type      = "Group"
      object_id = data.azuread_group.ot_oprt_is_general.object_id
    },
    {
      type      = "Group"
      object_id = data.azuread_group.ot_oprt_is_director.object_id
    }
  ]
}

# OwnerロールのPIM設定
resource "azurerm_role_management_policy" "owner_role_rules" {
  scope              = data.azurerm_subscription.this.id
  role_definition_id = data.azurerm_role_definition.subs_owner.id

  activation_rules {
    maximum_duration = "PT2H"
    require_multifactor_authentication = false
    required_conditional_access_authentication_context = null
    require_justification = true
    require_ticket_info   = false
    require_approval      = true

    approval_stage {
      dynamic "primary_approver" {
        for_each = local.pim_approvers
        content {
          type      = primary_approver.value.type
          object_id = primary_approver.value.object_id
        }
      }
    }
  }

  eligible_assignment_rules {
    expiration_required = false
    expire_after        = "P15D"
  }

  active_assignment_rules {
    expiration_required = true
    expire_after        = "P15D"
    require_multifactor_authentication = true
    require_justification = true
  }

  notification_rules {
    eligible_assignments {
      admin_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
    }
    active_assignments {
      admin_notifications {
        default_recipients    = true
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
    }
    eligible_activations {
      admin_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = true
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = true
        notification_level    = "All"
      }
    }
  }
}

# ContributorロールのPIM設定
resource "azurerm_role_management_policy" "contributor_role_rules" {
  scope              = data.azurerm_subscription.this.id
  role_definition_id = data.azurerm_role_definition.subs_contributor.id

  activation_rules {
    maximum_duration = "PT8H"
    require_multifactor_authentication = false
    required_conditional_access_authentication_context = null
    require_justification = true
    require_ticket_info   = false
    require_approval      = true

    approval_stage {
      dynamic "primary_approver" {
        for_each = local.pim_approvers
        content {
          type      = primary_approver.value.type
          object_id = primary_approver.value.object_id
        }
      }
    }
  }

  eligible_assignment_rules {
    expiration_required = false
    expire_after        = "P15D"
  }

  active_assignment_rules {
    expiration_required = true
    expire_after        = "P15D"
    require_multifactor_authentication = true
    require_justification = true
  }

  notification_rules {
    eligible_assignments {
      admin_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
    }
    active_assignments {
      admin_notifications {
        default_recipients    = true
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
    }
    eligible_activations {
      admin_notifications {
        default_recipients    = false
        additional_recipients = []
        notification_level    = "All"
      }
      assignee_notifications {
        default_recipients    = true
        additional_recipients = []
        notification_level    = "All"
      }
      approver_notifications {
        default_recipients    = true
        notification_level    = "All"
      }
    }
  }
}


output "debug_project_name"  { value = var.project_name }
output "debug_purpose_name"  { value = var.purpose_name }
output "debug_project_slug"  { value = local.project_slug }
output "debug_purpose_slug"  { value = local.purpose_slug }
output "debug_base_parts"    { value = local.base_parts }
output "base_naming"         { value = local.base }
output "rg_expected_name"    { value = local.name_rg }
output "vnet_expected_name"  { value = local.name_vnet }
output "subscription_id"     { value = local.effective_spoke_subscription_id != "" ? local.effective_spoke_subscription_id : null }
output "spoke_rg_name"       { value = azurerm_resource_group.rg.name }
output "spoke_vnet_name"     { value = azurerm_virtual_network.vnet.name }
output "hub_to_spoke_peering_id" { value = azurerm_virtual_network_peering.hub_to_spoke.id }
output "spoke_to_hub_peering_id" { value = azurerm_virtual_network_peering.spoke_to_hub.id }
output "bastion_host_id"     { value = azurerm_bastion_host.bastion.id }
output "bastion_public_ip"   { value = azurerm_public_ip.bastion_pip.ip_address }
output "natgw_id"            { value = local.is_public && length(azurerm_nat_gateway.natgw) > 0 ? azurerm_nat_gateway.natgw[0].id : null }
output "natgw_public_ip"     { value = local.is_public && length(azurerm_public_ip.natgw_pip) > 0 ? azurerm_public_ip.natgw_pip[0].ip_address : null }
