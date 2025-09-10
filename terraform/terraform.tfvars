# ===========================================
# 命名に使う変数（変更するとリソース名が変わる＝置換扱い）
# base = <project>-<purpose>-<environment_id>-<region_code>-<sequence>
# ===========================================
project_name   = "bft"      # PJ/案件名（小文字・一部記号はハイフンにスラッグ化）
purpose_name   = "kensho5"   # 用途（"検証" の場合は "kensho" にフォールバック）
environment_id = "prd"       # 環境識別子（例: dev/stg/prd）
region_code    = "jpe"       # リージョン略号（名前のみで使用、region と整合させる）
sequence       = "001"       # 識別番号（ゼロパディング推奨）

# ===========================================
# 配置リージョン（名前には影響しない）
# ===========================================
region = "japaneast"         # Azure の実リージョン（location）。変更は再作成になりやすい

# ==============================
# Subscription (Step0) 作成/再利用の制御
# ==============================
create_subscription   = true                       # 新規作成ならtrue
#create_subscription   = false                       # 既存再利用なら false
#spoke_subscription_id = "7cbfacbd-3c24-4051-8c08-f8b1a1145a3e"  # 既存 Spoke の Subscription ID
subscription_workload = "Production"                # 新規作成時のみ利用（Alias の workload）

# 課金系（現行 main.tf では未参照。将来の拡張向けに残置）
billing_account_name = "0ae846b2-3157-5400-bf84-d255f8f82239:d68ce096-f337-4c84-9d39-05562a37bab0_2019-05-31"
billing_profile_name = "IAMZ-4Q5A-BG7-PGB"
invoice_section_name = "6HB2-O3GL-PJA-PGB"

# 管理グループ（現行 main.tf では未参照。将来の拡張向けに残置）
management_group_id = "/providers/Microsoft.Management/managementGroups/mg-bft-test"

# ==============================
# VNet / Subnet / NSG (Step1-3)
# ==============================
# アドレス関連
ipam_pool_id         = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"
vnet_number_of_ips   = 1024   # /22 相当（変更で再作成の可能性）
subnet_number_of_ips = 256    # /24 相当（変更で再作成の可能性）

# セキュリティ関連（NSG ルール）
vpn_client_pool_cidr = "172.16.201.0/24"  # 許可ルールの送信元
allowed_port         = 3389               # 許可する宛先ポート

# ==============================
# Hub Peering (Step4) - 既存参照
# ==============================
hub_subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436"
hub_rg_name         = "rg-test-hubnw-prd-jpe-001"
hub_vnet_name       = "vnet-test-hubnw-prd-jpe-001"
