# ===========================================================
# 命名・リージョン・リソース配置に関する変数定義例
# ===========================================================

## purpose_name は廃止（命名規則から用途要素を削除）
# リージョン略号（名前生成用）
region_code    = "jpe"

# リソース名につける識別番号（ゼロ埋め推奨）
sequence       = "001"

# ===========================================================
# Azure配置リージョン（リソース作成先）
# ===========================================================
region = "japaneast"

# ===========================================================
# Subscription情報（Step0: 既存または新規作成制御）
# ===========================================================
# 新規作成する場合のみ true、既存流用なら false
#create_subscription   = true
create_subscription   = false

# SpokeサブスクリプションID（既存利用時に指定）
spoke_subscription_id = "ebc7f56b-e245-4d10-b49a-59293a1e67f5"

# Workload種別
subscription_workload = "Production"

# 課金情報（現状main.tfでは未使用。将来拡張用として残置）
#EA環境では異なる想定
billing_account_name  = "0ae846b2-3157-5400-bf84-d255f8f82239:d68ce096-f337-4c84-9d39-05562a37bab0_2019-05-31"
billing_profile_name  = "IAMZ-4Q5A-BG7-PGB"
invoice_section_name  = "6HB2-O3GL-PJA-PGB"

# 管理グループ
#management_group_id   = "/providers/Microsoft.Management/managementGroups/mg-bft-test"

# ===========================================================
# VNet / Subnet / NSG構成
# ===========================================================
# IPAMプールID（VNet/Subnet共用）
ipam_pool_id                 = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"

# VNet/サブネット/BastionサブネットのIP数
vnet_number_of_ips           = 1024
subnet_number_of_ips         = 256
bastion_subnet_number_of_ips = 64

# VPNクライアント許可CIDR、RDP許可ポート
vpn_client_pool_cidr = "172.16.201.0/24"
allowed_port         = 3389

# ===========================================================
# Hub Peering構成情報
# ===========================================================
hub_subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436"
hub_rg_name         = "rg-test-hubnw-prd-jpe-001"
hub_vnet_name       = "vnet-test-hubnw-prd-jpe-001"
