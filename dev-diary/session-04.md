# Session 04 — 2026-11-19

**Goal (one thing):** Add GatewaySubnet and AzureFirewallSubnet to the hub VNet, then plan, apply, verify and destroy
**Time:** 1:00 AM – 1:20 AM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in a fresh terminal
- Added two `azurerm_subnet` blocks to main.tf: GatewaySubnet (10.0.1.0/27) and AzureFirewallSubnet (10.0.2.0/26)
- `terraform fmt`, `terraform validate`, `terraform plan`: Plan 4 to add
- `terraform apply`: hub resource group, VNet and both subnets created
- Portal check: vnet-hub-eus > Subnets shows both ✅
- `terraform destroy`: everything removed

## What broke
- Nothing reported

## What I learned
- Azure only places a VPN gateway in a subnet named exactly GatewaySubnet, and a firewall in one named exactly AzureFirewallSubnet
- /27 and /26 are the smallest sizes each allows, so I'm not wasting address space
- Subnets cost nothing; the gateway and firewall that go in them are the expensive parts

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- Add Spoke 1 VNet in East US
