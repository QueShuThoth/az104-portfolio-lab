# Session 14 — 2026-11-21

**Goal (one thing):** Wrap up the network lab: architecture diagram, README write-up and cost summary
**Time:** evening
**Recording:** not noted (no Granola notes for this session)

## What I did
- Wrote the top-level `README.md` for the repo
- Architecture diagram in Mermaid: simulated on-prem, the hub with its VPN gateway and Azure Firewall, Spoke 1 (East US) and Spoke 2 (West US), the S2S IPsec link, peering and the firewall routes
- "What's in it" table by layer: hub, spokes, peering, security, hybrid (toggle), firewall (toggle), plus the naming pattern
- On/off switch table: free core 22 resources, `enable_vpn_gateway` +8, `enable_firewall` +9
- Cost summary for Sessions 1 to 13, with the FinOps choices that kept it cheap
- Design decisions, what I'd add next, and a "Run it yourself" block linking `commands.md`
- Pushed the README to GitHub

## What broke
- Nothing noted

## What I learned
- The README is where the decisions get said out loud: no gateway transit, firewall IP read from Terraform, route tables in the same region as their subnet, secrets kept out of the repo
- Turning thirteen sessions into one cost table shows the FinOps story at a glance: the free core cost $0, and the billable parts only ran for minutes

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: not needed, nothing was built
- Cost: $0

## Next session's goal
- Start the RAG chatbot: a keyless Foundry resource with a chat model and an embedding model
