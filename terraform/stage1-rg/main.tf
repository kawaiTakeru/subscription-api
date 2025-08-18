terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
  }
}

provider "azurerm" {
  features {}
  # 認証は Pipeline 側で ARM_USE_AZCLI_AUTH=true を有効化し、AzureCLI@2 のログインを利用
}

resource "azurerm_resource_group" "this" {
  name     = var.rg_name
  location = var.location
}

output "rg_name" {
  value = azurerm_resource_group.this.name
}
output "rg_location" {
  value = azurerm_resource_group.this.location
}

