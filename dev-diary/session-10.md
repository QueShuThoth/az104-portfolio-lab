# Session 10 — 2026-11-20

**Goal (one thing):** Add the hub's VPN gateway behind an on/off toggle, switch it on for one apply, verify, then destroy
**Time:** late morning, about 10:45 AM – 11:18 AM (recording paused during create and destroy)
**Recording:** webcam ✅ · screen ✅

## What I did
- Set `ARM_SUBSCRIPTION_ID` in the terminal
- Confirmed the GatewaySubnet block's label was already `gateway`, so no change needed
- Added to main.tf: variable `enable_vpn_gateway` (bool, default `false`), `azurerm_public_ip.vpngw` (pip-vpngw-hub-eus, Static, Standard) and `azurerm_virtual_network_gateway.hub` (vpngw-hub-eus, RouteBased, Basic SKU, Generation1), both behind `count = var.enable_vpn_gateway ? 1 : 0`
- `terraform fmt`, `terraform validate`, `terraform plan`: 18 to add, same as Session 9, so the gateway stays off by default
- `terraform apply -var="enable_vpn_gateway=true"`: 20 to add (18 plus the public IP and the gateway). Created faster than the 30–45 minutes I expected
- Portal check: vpngw-hub-eus shows SKU Basic on Overview and Configuration, with a public IP ✅
- `terraform destroy` on all 20, then checked All resources in the portal: lab resources gone ✅

## What broke
- Nothing real. Mistyped `terraform` once (dropped the T) and retyped it

## What I learned
- The toggle is the FinOps lesson: `count = 0` means Terraform builds none of it, so a normal plan or apply can't turn the gateway on by accident. It only bills when I pass `-var="enable_vpn_gateway=true"` on purpose
- Since November 2025, Azure only lets you create zone-redundant gateway SKUs (VpnGw1AZ and up) or Basic. Basic is the cheapest and still does route-based site-to-site
- A Basic gateway now needs a Standard SKU public IP (Basic public IPs are retired)
- Gateways bill until the delete finishes, so destroy right after verifying

## Azure cost check
- Resources left running: none from the lab
- `terraform destroy` run: yes
- Cost: a few cents (Basic gateway billed only for the time it was up)

## Next session's goal
- Simulated on-prem site and the site-to-site VPN connection
