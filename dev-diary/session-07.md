# Session 07 — 2026-11-19

**Goal (one thing):** Add Spoke 2 in West US, then plan, apply, verify and destroy
**Time:** evening, wrapped up by 8:22 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Added Spoke 2 to main.tf: `rg-lab-spoke2-wus` (westus), `vnet-spoke2-wus` on 10.2.0.0/16, `snet-workload` on 10.2.1.0/24
- Saved before running anything
- `terraform fmt`, `terraform validate` (valid), `terraform plan`: Plan 12 to add (9 from Session 6 plus 3)
- `terraform apply`: 12 resources added
- Portal check: rg-lab-spoke2-wus location shows West US ✅; vnet-spoke2-wus > Subnets lists snet-workload ✅
- `terraform destroy`: Destroy complete, 12 destroyed (VNets gone in about 11s, resource groups in about 21s)

## What broke
- Nothing in the build. On camera I said Spoke 2 was "10.200"; the code is 10.2.0.0/16
- Destroy ran but didn't make it into the recording; the terminal shows 12 destroyed

## What I learned
- A second region is the same Terraform shape with a different `location`; the resource group's region carries down to the VNet
- Each spoke gets its own /16 (10.0 hub, 10.1 Spoke 1, 10.2 Spoke 2) so peering stays possible
- Peering across regions (Session 8) is global peering, billed a bit more per GB, still $0 with no traffic

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- Global peering between the hub and Spoke 2 (expect Plan: 14 to add)
