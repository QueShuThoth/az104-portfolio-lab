# az104-portfolio-lab
Secure multi-region hybrid network on Azure, built with Terraform
## Plan
- Hub VNet (East US): VPN gateway, Azure Firewall
- Spoke 1 (East US) and Spoke 2 (West US), peered to the hub
- Simulated on-prem site over site-to-site VPN

## Naming
rg-lab-<role>-<region>, vnet-<role>-<region>