# Session 08 — 2026-11-19

**Goal (one thing):** Peer the hub and Spoke 2 across regions (global peering), then plan, apply, verify and destroy
**Time:** 8:26 PM – 8:37 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Added two `azurerm_virtual_network_peering` blocks to main.tf: peer-hub-to-spoke2 and peer-spoke2-to-hub, both with `allow_forwarded_traffic = true`
- Saved before running anything
- `terraform fmt`, `terraform validate`, `terraform plan`: Plan 14 to add (12 from Session 7 plus 2 peerings)
- `terraform apply`: completed
- Portal check: peerings show Connected, fully synchronized ✅
- `terraform destroy`: destroy confirmed on camera, then checked the portal to make sure nothing was left

## What broke
- Nothing. Clean run, one plan

## What I learned
- Same Terraform as Session 6; peering East US to West US is what makes it global peering
- Global peering bills per GB a bit higher than same-region peering; with no traffic it costs nothing
- The hub is now peered to both spokes, but the spokes aren't peered to each other, and peering isn't transitive. Routing spoke-to-spoke traffic through the hub is the firewall's job later

## Azure cost check
- Resources left running: none (confirmed in portal)
- `terraform destroy` run: yes

## Next session's goal
- Network security groups on the spoke workload subnets
