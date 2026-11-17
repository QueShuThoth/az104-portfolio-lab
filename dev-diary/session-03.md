# Session 03 — 2026-11-17

**Goal (one thing):** Run `terraform apply`, confirm the hub resource group and VNet in the portal, then `terraform destroy`
**Time:** 4:15 PM – 5:05 PM
**Recording:** webcam ✅ · screen ✅

## Before the session
- Fixed OBS audio: Audio Track 1 only, QuickSync H.264, plain MP4
- Turned on Windows Studio Effects eye contact for the webcam; confirmed it works in OBS
- Recorded the Sessions 1 & 2 recap bookend

## What I did
- Set `ARM_SUBSCRIPTION_ID` in a new terminal (prints nothing, which keeps the ID off screen)
- `terraform apply`: Plan 2 to add, 0 to change, 0 to destroy. Apply complete: resource group in 23s, VNet in 20s
- Portal check: rg-lab-hub-eus contains vnet-hub-eus ✅
- `terraform destroy`: Destroy complete, both resources removed

## What broke
- No errors
- VS Code showed a warning on the terminal tab after an extension changed its environment. Harmless; a relaunched terminal needs `ARM_SUBSCRIPTION_ID` set again

## What I learned
- apply shows the same plan again and waits for `yes`, so you get a last check before anything is built
- Apply output and terraform.tfstate both contain the subscription ID: blur it in recordings, and keep tfstate out of Git (.gitignore already does)
- Full deploy-and-teardown loop works, so I can build and destroy per session and keep costs near zero

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- Add the hub subnets (GatewaySubnet, AzureFirewallSubnet) to main.tf, plan, apply, verify, destroy
