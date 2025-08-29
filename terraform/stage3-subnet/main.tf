terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # ★ ここも v4 系に更新
      version = "~> 4.41"
    }
  }
}

provider "azurerm" {
  features {}
}

# 参照
data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# NSG（VPN クライアントからのみ許可 + それ以外 Inbound Deny）
resource "azurerm_network_security_group" "private" {
  name                = var.nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-VPN-RDP"
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
    name                       = "Deny-Internet-Inbound"
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

# Subnet（IPAM から /24 相当などを自動割当）
resource "azurerm_subnet" "private" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name

  # ★ address_prefixes は使わず、IPAM のプールから自動割当
  ip_address_pool {
    id                     = var.ipam_pool_id
    number_of_ip_addresses = var.subnet_number_of_ips
  }
}

# Subnet と NSG を関連付け
resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

output "subnet_id" {
  value = azurerm_subnet.private.id
}
