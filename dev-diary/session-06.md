# Session 06 — 2026-11-19

**Goal (one thing):** Peer the hub and Spoke 1, then plan, apply, verify and destroy
**Time:** 2:12 AM – 2:25 AM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Added two `azurerm_virtual_network_peering` blocks to main.tf: peer-hub-to-spoke1 and peer-spoke1-to-hub, both with `allow_forwarded_traffic = true`
- Saved with Ctrl+S before running anything
- `terraform fmt`, `terraform validate` (Configuration valid), `terraform plan`: Plan 9 to add (7 from Session 5 plus 2 peerings)
- `terraform apply`: 9 resources added
- Portal check: vnet-hub-eus > Peerings shows Connected, fully synchronized ✅; vnet-spoke1-eus > Peerings shows Connected ✅
- `terraform destroy`: everything removed

## What broke
- Nothing. Saving first meant one clean plan, no repeat of Session 5

## What I learned
- A peering goes one way, so each VNet needs its own peering to the other before either shows Connected
- Peering bills only for data that crosses it; with no traffic it costs nothing
- `allow_forwarded_traffic` lets traffic the hub passes along (later, through the firewall) reach the spoke

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- Spoke 2 in West US
