# ===========================================
# 命名用 基本入力（この2つを更新すれば全命名が変わります）
# ===========================================
project_name   = "BFT"   # <PJ/案件名>
purpose_name   = "検証"   # <用途>（ASCII へ: 検証→kensho）

# 命名の共通コンテキスト
environment_id = "prd"   # <環境識別子>
region         = "japaneast"
region_code    = "jpe"   # <リージョン略号>
sequence       = "001"   # <識別番号>

# ==============================
# Subscription (Step0)
# ==============================
billing_account_name  = "0ae846b2-3157-5400-bf84-d255f8f82239:d68ce096-f337-4c84-9d39-05562a37bab0_2019-05-31"
billing_profile_name  = "IAMZ-4Q5A-BG7-PGB"
invoice_section_name  = "6HB2-O3GL-PJA-PGB"
subscription_workload = "Production"
create_subscription   = true
# spoke_subscription_id = ""  # 既存を使う場合に設定（Step0 で override.auto.tfvars に注入されます）
management_group_id   = "/providers/Microsoft.Management/managementGroups/mg-bft-test"

# ==============================
# VNet / Subnet / NSG (Step1-3)
# ==============================
ipam_pool_id         = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"
vnet_number_of_ips   = 1024  # /22 相当
subnet_number_of_ips = 256   # /24 相当
vpn_client_pool_cidr = "172.16.201.0/24"
allowed_port         = 3389

# ==============================
# Hub Peering (Step4)
# ==============================
# 既存の Hub リソース（参照のみ。新規作成はしません）
hub_subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436"   # 既存 Hub Subscription ID
hub_vnet_name       = "vnet-test-hubnw-prd-jpe-001"           # 既存 Hub VNet 名
hub_rg_name         = "rg-test-hubnw-prd-jpe-001"             # 既存 Hub RG 名
