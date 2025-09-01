# ==============================
# Subscription (Step0)
# ==============================
subscription_alias_name   = "cr_subscription_test_109"
subscription_display_name = "CR 検証サブスクリプション 109"
billing_account_name      = "0ae846b2-3157-5400-bf84-d255f8f82239:d68ce096-f337-4c84-9d39-05562a37bab0_2019-05-31"
billing_profile_name      = "IAMZ-4Q5A-BG7-PGB"
invoice_section_name      = "6HB2-O3GL-PJA-PGB"
subscription_workload     = "Production"
create_subscription       = true

# create_subscription=false の場合はここに既存 subscription を直接記載:
# spoke_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# ==============================
# Hub (Peering)
# ==============================
hub_subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436"
hub_vnet_name       = "vnet-test-hubnw-prd-jpe-001"
hub_rg_name         = "rg-test-hubnw-prd-jpe-001"

# ==============================
# RG (Step1)
# ==============================
rg_name  = "rg-from-pipeline"
location = "japaneast"

# ==============================
# VNet (Step2)
# ==============================
vnet_name         = "vnet-from-pipeline"
ipam_pool_id      = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"
vnet_number_of_ips = 1024  # /22 相当

# ==============================
# Subnet + NSG (Step3)
# ==============================
subnet_name          = "subnet-from-pipeline"
subnet_number_of_ips = 256     # /24 相当
nsg_name             = "nsg-private-subnet"
vpn_client_pool_cidr = "172.16.201.0/24"
allowed_port         = 3389
