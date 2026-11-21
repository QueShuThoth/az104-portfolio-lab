terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "hub" {
  name     = "rg-lab-hub-eus"
  location = "eastus"
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/27"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_resource_group" "spoke1" {
  name     = "rg-lab-spoke1-eus"
  location = "eastus"
}

resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-eus"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "spoke1_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = "peer-hub-to-spoke1"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = "peer-spoke1-to-hub"
  resource_group_name       = azurerm_resource_group.spoke1.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_resource_group" "spoke2" {
  name     = "rg-lab-spoke2-wus"
  location = "westus"
}

resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-wus"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = "peer-hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = "peer-spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.spoke2.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_network_security_group" "spoke1" {
  name                = "nsg-spoke1-eus"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name

  security_rule {
    name                       = "Allow-SSH-From-Hub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke1_workload" {
  subnet_id                 = azurerm_subnet.spoke1_workload.id
  network_security_group_id = azurerm_network_security_group.spoke1.id
}

resource "azurerm_network_security_group" "spoke2" {
  name                = "nsg-spoke2-wus"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name

  security_rule {
    name                       = "Allow-SSH-From-Hub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke2_workload" {
  subnet_id                 = azurerm_subnet.spoke2_workload.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}

variable "enable_vpn_gateway" {
  description = "Turn the VPN gateway on (true) or off (false). It bills by the hour."
  type        = bool
  default     = false
}

resource "azurerm_public_ip" "vpngw" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "pip-vpngw-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "hub" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "vpngw-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "Basic"
  generation          = "Generation1"
  active_active       = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpngw[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

variable "vpn_shared_key" {
  description = "Shared key for the S2S connection. Set with TF_VAR_vpn_shared_key, never in a file."
  type        = string
  sensitive   = true
  default     = null
}

# Simulated on-prem network (free)
resource "azurerm_resource_group" "onprem" {
  name     = "rg-lab-onprem-eus"
  location = "eastus"
}

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem-eus"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  address_space       = ["192.168.0.0/16"]
}

resource "azurerm_subnet" "onprem_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["192.168.1.0/27"]
}

# On-prem "VPN device" (bills by the hour, same toggle)
resource "azurerm_public_ip" "onprem_vpngw" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "pip-vpngw-onprem-eus"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "onprem" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "vpngw-onprem-eus"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "Basic"
  generation          = "Generation1"
  active_active       = false
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem_vpngw[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem_gateway.id
  }
}

# Each side's record of the other side
resource "azurerm_local_network_gateway" "onprem" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "lng-onprem-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  gateway_address     = azurerm_public_ip.onprem_vpngw[0].ip_address
  address_space       = ["192.168.0.0/16"]
}

resource "azurerm_local_network_gateway" "hub" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "lng-hub-eus"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  gateway_address     = azurerm_public_ip.vpngw[0].ip_address
  address_space       = ["10.0.0.0/16"]
}

# The tunnel, one connection from each end
resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem" {
  count                      = var.enable_vpn_gateway ? 1 : 0
  name                       = "cn-hub-to-onprem"
  location                   = azurerm_resource_group.hub.location
  resource_group_name        = azurerm_resource_group.hub.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem[0].id
  shared_key                 = var.vpn_shared_key
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub" {
  count                      = var.enable_vpn_gateway ? 1 : 0
  name                       = "cn-onprem-to-hub"
  location                   = azurerm_resource_group.onprem.location
  resource_group_name        = azurerm_resource_group.onprem.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.hub[0].id
  shared_key                 = var.vpn_shared_key
}

variable "enable_firewall" {
  description = "Turn Azure Firewall on (true) or off (false). It bills by the hour."
  type        = bool
  default     = false
}

# Management subnet that Basic tier requires (free)
resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/26"]
}

resource "azurerm_public_ip" "firewall" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-afw-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "firewall_mgmt" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-afw-mgmt-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "hub" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afwp-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Basic"
}

resource "azurerm_firewall" "hub" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afw-hub-eus"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id

  ip_configuration {
    name                 = "afw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  management_ip_configuration {
    name                 = "afw-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.firewall_mgmt[0].id
  }
}

# Firewall rule: let the two spokes talk to each other
resource "azurerm_firewall_policy_rule_collection_group" "spokes" {
  count              = var.enable_firewall ? 1 : 0
  name               = "rcg-spokes"
  firewall_policy_id = azurerm_firewall_policy.hub[0].id
  priority           = 200

  network_rule_collection {
    name     = "allow-spoke-to-spoke"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "spoke1-to-spoke2"
      protocols             = ["Any"]
      source_addresses      = ["10.1.0.0/16"]
      destination_addresses = ["10.2.0.0/16"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "spoke2-to-spoke1"
      protocols             = ["Any"]
      source_addresses      = ["10.2.0.0/16"]
      destination_addresses = ["10.1.0.0/16"]
      destination_ports     = ["*"]
    }
  }
}

# Route tables: send spoke traffic to the firewall
resource "azurerm_route_table" "spoke1" {
  count                         = var.enable_firewall ? 1 : 0
  name                          = "rt-spoke1-eus"
  location                      = azurerm_resource_group.spoke1.location
  resource_group_name           = azurerm_resource_group.spoke1.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "to-spoke2-via-firewall"
    address_prefix         = "10.2.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_route_table" "spoke2" {
  count                         = var.enable_firewall ? 1 : 0
  name                          = "rt-spoke2-wus"
  location                      = azurerm_resource_group.spoke2.location
  resource_group_name           = azurerm_resource_group.spoke2.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "to-spoke1-via-firewall"
    address_prefix         = "10.1.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke1_workload" {
  count          = var.enable_firewall ? 1 : 0
  subnet_id      = azurerm_subnet.spoke1_workload.id
  route_table_id = azurerm_route_table.spoke1[0].id
}

resource "azurerm_subnet_route_table_association" "spoke2_workload" {
  count          = var.enable_firewall ? 1 : 0
  subnet_id      = azurerm_subnet.spoke2_workload.id
  route_table_id = azurerm_route_table.spoke2[0].id
}