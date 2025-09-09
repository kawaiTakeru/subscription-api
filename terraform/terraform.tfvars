# ===========================================
# 命名用 基本入力（この2つを更新すれば全命名が変わります）
# ===========================================
project_name = "bft2"
purpose_name = "kensho2"

# 命名の共通コンテキスト
environment_id = "prd"
region         = "japaneast"
region_code    = "jpe"
sequence       = "001"

# ==============================
# Subscription (Step0)
# ==============================
billing_account_name  = "0ae846b2-3157-5400-bf84-d255f8f82239:d68ce096-f337-4c84-9d39-05562a37bab0_2019-05-31"
billing_profile_name  = "IAMZ-4Q5A-BG7-PGB"
invoice_section_name  = "6HB2-O3GL-PJA-PGB"
subscription_workload = "Production"

# 今回は新規作成
create_subscription   = true
# 既存再利用する場合はこちらを使う
# create_subscription   = false
# spoke_subscription_id = "<existing-guid>"

management_group_id = "/providers/Microsoft.Management/managementGroups/mg-bft-test"

# ==============================
# VNet / Subnet / NSG (Step1-3)
# ==============================
ipam_pool_id         = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"
vnet_number_of_ips   = 1024
subnet_number_of_ips = 256
vpn_client_pool_cidr = "172.16.201.0/24"
allowed_port         = 3389

# ==============================
# Hub Peering (Step4) - 既存参照
# ==============================
hub_subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436"
hub_vnet_name       = "vnet-test-hubnw-prd-jpe-001"
hub_rg_name         = "rg-test-hubnw-prd-jpe-001"
