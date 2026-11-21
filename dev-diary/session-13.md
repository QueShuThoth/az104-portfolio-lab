# Session 13 — 2026-11-21

**Goal (one thing):** Send spoke traffic through the firewall with route tables, verify, then destroy
**Time:** late morning to midday, wrapped up about 12:40 PM (recording paused during create and destroy)
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Added to main.tf, all behind `enable_firewall`: `azurerm_firewall_policy_rule_collection_group.spokes` (rcg-spokes, network rule collection allow-spoke-to-spoke, both directions), `azurerm_route_table.spoke1` (rt-spoke1-eus) and `.spoke2` (rt-spoke2-wus, West US) with routes to the other spoke and to 0.0.0.0/0, next hop Virtual appliance = the firewall's private IP read from Terraform, BGP route propagation off, plus `azurerm_subnet_route_table_association` for both workload subnets
- `terraform validate`, then `terraform plan` with the switch off: 22 to add, same as Session 12
- `terraform plan -var="enable_firewall=true"`: 31 to add (26 plus the rule group, 2 route tables, 2 subnet links)
- `terraform apply -var="enable_firewall=true"`
- Portal check: rt-spoke1-eus and rt-spoke2-wus both show 2 routes with next hop Virtual appliance at the firewall IP, and snet-workload linked ✅
- Portal check: afwp-hub-eus network rules show allow-spoke-to-spoke ✅
- `terraform destroy`, then checked All resources: only Network Watchers left (free) ✅

## What broke
- Nothing

## What I learned
- A route table (user-defined routes) overrides Azure's default routing for a subnet. Next hop type Virtual appliance sends traffic to an IP, here the firewall
- The spokes aren't peered to each other, so the firewall is the only path between them. That's the point of hub-and-spoke
- Internet traffic from the spokes now goes through the firewall too, and with no rule allowing it, it's blocked by default. That's the secure starting point
- A route table has to live in the same region as the subnet it's linked to, so Spoke 2's table is in West US
- Reading the firewall IP from Terraform means I never hard-code it

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: yes
- Cost: well under a dollar (Basic firewall billed only while it was up)

## Next session's goal
- Wrap-up: architecture diagram, README write-up and cost summary
