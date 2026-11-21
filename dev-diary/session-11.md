# Session 11 — 2026-11-21

**Goal (one thing):** Build a simulated on-prem network and connect it to the hub over a site-to-site VPN
**Time:** morning, wrapped up about 8:10 AM (recording paused during create and destroy)
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` and generated a random VPN shared key into `TF_VAR_vpn_shared_key`, terminal only, never in a file
- Added to main.tf: sensitive variable `vpn_shared_key`; free on-prem pieces (rg-lab-onprem-eus, vnet-onprem-eus 192.168.0.0/16, its GatewaySubnet 192.168.1.0/27); and behind `enable_vpn_gateway`: on-prem public IP, vpngw-onprem-eus (Basic), local network gateways lng-onprem-eus and lng-hub-eus, and IPsec connections hub-to-onprem and onprem-to-hub
- `terraform plan` with the switch off: 21 to add (18 plus the on-prem resource group, VNet and gateway subnet)
- `terraform apply -var="enable_vpn_gateway=true"`: 29 to add (2 gateways, 2 public IPs, 2 local network gateways, 2 connections on top). Created quickly
- Waited about 5 minutes, then checked both connections in the portal: hub side Connected ✅, on-prem side Connected ✅
- Looked at the topology in the Azure resource visualizer
- `terraform destroy`, then checked All resources: only Network Watcher items left (free) ✅

## What broke
- Nothing. All commands worked first time

## What I learned
- A site-to-site VPN needs a pair on each side: a VPN gateway, a local network gateway describing the other side's public IP and address range, and a connection using the same shared key
- Connections can show Not connected for a few minutes after apply while the tunnel negotiates
- Marking the shared key `sensitive` and passing it through `TF_VAR_` keeps it out of the repo and out of plan output
- On-prem can reach the hub but not the spokes yet; that needs gateway transit on the peerings

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: yes
- Cost: roughly 10 cents (two Basic gateways plus IPs, list price not verified)

## Next session's goal
- Azure Firewall in the hub, behind its own toggle
