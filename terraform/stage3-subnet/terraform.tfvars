# ==== 実行環境ごとに合わせて設定 ====
subscription_id = "f5df22f6-d4ab-4e1a-8544-96e717526b47"
tenant_id       = "2b72ff53-757a-41b9-aa8f-7056292c626e"

rg_name              = "rg-from-pipeline"
vnet_name            = "vnet-from-pipeline"
subnet_name          = "subnet-from-pipeline"
nsg_name             = "nsg-private-subnet"
vpn_client_pool_cidr = "172.16.201.0/24"

# VNet と同じ root プールを参照（必要に応じて将来“子プール”に分割可能）
ipam_pool_id         = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"

# 例：/24 相当（= 256 IP）
subnet_number_of_ips = 256
