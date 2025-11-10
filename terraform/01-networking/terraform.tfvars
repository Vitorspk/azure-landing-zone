# Network Configuration
# All settings use defaults from variables.tf
# Uncomment and modify if you need to override defaults

resource_group_name = "rg-network"
vnet_name           = "vnet-shared-network"
vnet_address_space  = "192.168.0.0/16"

# Tags
tags = {
  Project     = "azure-landing-zone"
  ManagedBy   = "terraform"
  Environment = "shared"
  CostCenter  = "infrastructure"
}
