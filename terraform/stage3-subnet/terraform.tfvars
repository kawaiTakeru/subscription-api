rg_name              = "rg-from-pipeline"
vnet_name            = "vnet-from-pipeline"
subnet_name          = "subnet-from-pipeline"
nsg_name             = "nsg-private-subnet"
vpn_client_pool_cidr = "172.16.201.0/24"

# ここも同じプールを指してOK（あるいは子プールを作って分ける運用も可）
ipam_pool_id         = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"

# 例：/24 相当
subnet_number_of_ips = "256"
