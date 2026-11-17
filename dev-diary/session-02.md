# Session 02 — 2026-11-17

**Goal (one thing):** Get a clean `terraform plan` for the hub resource group and VNet
**Time:** 1:00 PM – 2:09 PM
**Recording:** phone ❌ · screen ❌ (bookend recorded before Session 03)

## What I did
- Set up budget alerts on my lab subscription: budget-lab-monthly ($20) and Pocket_Change ($10), both monthly
- Saved Session 01 log to dev-diary and committed it
- Signed in with `az login` and confirmed `az account show` points at my personal lab tenant
- Installed Terraform v1.17.1 with winget
- Created main.tf: rg-lab-hub-eus + vnet-hub-eus (10.0.0.0/16), azurerm ~> 4.0
- Set subscription through ARM_SUBSCRIPTION_ID env var so the ID stays out of the public repo
- `terraform init` + `terraform plan`: **Plan: 2 to add, 0 to change, 0 to destroy** (resource group + VNet)

## What broke
- Error: `terraform` not recognized as a cmdlet
- Fix: Terraform wasn't installed. Installed it with winget
- Error: still not recognized right after install
- Fix: the open shell had the old PATH. Opened a new window and it worked
- Also: repo had no main.tf yet, so there was nothing to plan

## What I learned
- `az login` working doesn't mean Terraform is installed. They're separate tools
- azurerm 4.x needs a subscription ID; an env var keeps it out of Git
- New tools change PATH, so restart the terminal after installing

## Azure cost check
- Resources left running: none (plan only, nothing applied)
- `terraform destroy` run: not needed

## Next session's goal
- Run `terraform apply`, confirm the resource group and VNet in the portal, then `terraform destroy`
