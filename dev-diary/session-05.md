# Session 05 — 2026-11-19

**Goal (one thing):** Add Spoke 1 in East US, then plan, apply, verify and destroy
**Time:** 1:20 AM – 2:00 AM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Pasted three new blocks into main.tf: rg-lab-spoke1-eus, vnet-spoke1-eus (10.1.0.0/16) and subnet snet-workload (10.1.1.0/24)
- `terraform validate`: success
- `terraform plan`: showed 4 to add instead of 7 (see What broke)
- Saved main.tf, ran `terraform destroy`, then validate, plan (7 to add) and `terraform apply`: all 7 created
- Portal check: rg-lab-spoke1-eus, vnet-spoke1-eus and snet-workload all present ✅
- `terraform destroy`: everything removed

## What broke
- I pasted the spoke blocks but didn't save main.tf, so Terraform only saw the hub and planned 4 to add. The first apply built only the hub, and the spoke wasn't in the portal
- Fix: saved the file, then re-ran plan and apply. I destroyed first to start clean, but that wasn't needed: re-planning after the save would have shown just the 3 missing spoke resources

## What I learned
- Terraform reads the file on disk, not what's in the editor. Always save before plan or apply (a dot or circle on the VS Code tab means unsaved)
- Terraform compares the file to what already exists and only adds the difference, so fixing a mistake doesn't require tearing everything down
- Spoke 1 (10.1.0.0/16) and the hub (10.0.0.0/16) don't overlap, which peering requires

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- Peer the hub and Spoke 1
