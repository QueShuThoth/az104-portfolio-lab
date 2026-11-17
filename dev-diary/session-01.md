# Session 01 — 2026-11-16

**Goal (one thing):** Set up the repo and plan before deploying anything
**Time:** evening (fill in)
**Recording:** phone ❌ · screen ❌ (diary started after this session)

## What I did
- Created az104-portfolio-lab repo at C:\dev with GitHub Desktop
- Added Terraform .gitignore and MIT license, published to GitHub
- Wrote README plan: hub VNet (East US) with VPN gateway and Azure Firewall, two peered spokes (East US, West US), simulated on-prem over site-to-site VPN
- Set naming convention: rg-lab-<role>-<region>, vnet-<role>-<region>
- Planned a $20/month budget alert at 80% on my personal subscription (set up in Session 02)

## What broke
- No errors

## What I learned
- Guardrails first: budget alert before any resource goes up
- Keep lab work off the work tenant

## Azure cost check
- Resources left running: none (nothing deployed yet)
- `terraform destroy` run: not needed

## Next session's goal
- Set up the budget alert, then run `terraform init` and get a clean `terraform plan` on the hub resource group and VNet
