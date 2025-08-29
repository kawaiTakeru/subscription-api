rg_name  = "rg-from-pipeline"
vnet_name = "vnet-from-pipeline"

# あなたの IPAM プール（root-10-20）のリソースIDをそのまま
ipam_pool_id       = "/subscriptions/6a018b75-55b5-4b68-960d-7328148568aa/resourceGroups/rg-apim-dev/providers/Microsoft.Network/networkManagers/nm-apimdev-ipam/ipamPools/root-10-20"

# 例：/22 相当（= 1024 IP）
vnet_number_of_ips = 1024
