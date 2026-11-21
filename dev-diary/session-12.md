# Session 12 — 2026-11-21

**Goal (one thing):** Add Azure Firewall to the hub behind its own on/off switch, turn it on for one apply, verify, then destroy
**Time:** morning, wrapped up about 8:45 AM (recording paused during create and destroy)
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Checked the AzureFirewallSubnet block: label already `firewall`, so no change needed
- Added to main.tf: variable `enable_firewall` (default `false`), `azurerm_subnet.firewall_mgmt` (AzureFirewallManagementSubnet 10.0.3.0/26, free), and behind the switch: two Standard public IPs (pip-afw-hub-eus, pip-afw-mgmt-hub-eus), `azurerm_firewall_policy.hub` (afwp-hub-eus, Basic) and `azurerm_firewall.hub` (afw-hub-eus, AZFW_VNet, Basic tier)
- `terraform plan` with both switches off: 22 to add (21 plus the management subnet). Had to save first and re-run
- `terraform plan -var="enable_firewall=true"`: 26 to add (22 plus 2 public IPs, the policy and the firewall)
- `terraform apply -var="enable_firewall=true"`
- Portal check: afw-hub-eus shows Basic tier, policy attached, private IP in 10.0.2.x (noted for Session 13) ✅
- `terraform destroy`, then checked All resources: only Network Watchers left (free) ✅

## What broke
- Nothing. Briefly edited the firewall subnet's resource_group_name by mistake, caught it and put it back before applying. Forgot Ctrl+S once before the first plan

## What I learned
- Azure Firewall Basic needs its own AzureFirewallManagementSubnet (/26 minimum) and a second public IP, used only for Microsoft's management traffic
- Basic only works with a Firewall Policy, not classic rules
- Each costly piece gets its own switch, so I can run the firewall without the VPN gateways and only pay for what I'm testing

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: yes
- Cost: well under a dollar (Basic firewall billed only while it was up; list price not verified)

## Next session's goal
- Route tables that send spoke traffic through the firewall
