# Session 09 — 2026-11-20

**Goal (one thing):** Put a network security group (NSG) on each spoke's workload subnet, then plan, apply, verify and destroy
**Time:** morning, about 10:15 AM – 10:29 AM
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Added to main.tf: `nsg-spoke1-eus` and `nsg-spoke2-wus`, each with one inbound rule, Allow-SSH-From-Hub (priority 100, TCP 22, source 10.0.0.0/16)
- Linked each NSG to its spoke's `snet-workload` with `azurerm_subnet_network_security_group_association`
- `terraform fmt`, `terraform validate`, `terraform plan`: Plan 18 to add (14 from Session 8 plus 2 NSGs and 2 subnet links)
- `terraform apply`: completed
- Portal check: on both NSGs, Allow-SSH-From-Hub sits at priority 100 above the default rules, and snet-workload is listed under Subnets ✅
- `terraform destroy`: completed, said on camera

## What broke
- Nothing. Clean run

## What I learned
- My rule is the one door opened on purpose. The default rules allow traffic inside the VNet and its peers and deny inbound from the internet
- Linking the NSG to the subnet instead of each VM's NIC means one NSG covers every VM added later: fewer objects to manage (FinOps)
- NSGs are free

## Azure cost check
- Resources left running: none
- `terraform destroy` run: yes

## Next session's goal
- VPN gateway, the first resource that costs money, behind an on/off toggle
