# AZ-104 Lab: Command Reference

Run everything from the repo folder in the VS Code terminal (`C:\Dev\az104-portfolio-lab`).
Open the terminal: **Ctrl + `**

---

## The session loop (every session)

```powershell
# 1. Sign in and confirm you're on the lab subscription
az login
az account show --query name -o tsv

# 2. Point Terraform at the subscription (prints nothing, keeps the ID off screen)
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)

# 3. Preview, build, tear down
terraform plan
terraform apply      # type: yes
terraform destroy    # type: yes
```

Rule: **a new terminal forgets `ARM_SUBSCRIPTION_ID`.** Run step 2 again after any relaunch.

---

## Terraform

| Command | What it does |
|---|---|
| `terraform -version` | Check Terraform is installed |
| `terraform init` | Download providers. Run once per repo, and again after adding a provider |
| `terraform fmt` | Tidy the spacing in your .tf files |
| `terraform validate` | Check the syntax before planning |
| `terraform plan` | Show what would change. Changes nothing |
| `terraform apply` | Show the plan again, then build on `yes` |
| `terraform destroy` | Delete everything this repo built, on `yes` |
| `terraform state list` | List what Terraform thinks exists right now |
| `terraform output` | Show output values (once you add outputs) |

Read the plan line before typing yes: **`Plan: X to add, Y to change, Z to destroy`.**
Anything in "to destroy" that you didn't expect, stop and check.

---

## Azure CLI

| Command | What it does |
|---|---|
| `az login` | Sign in |
| `az account show` | Show the current subscription |
| `az account list -o table` | List all your subscriptions |
| `az group list -o table` | List resource groups |
| `az resource list -o table` | List every resource (cost check: should be empty after destroy) |
| `az network vnet list -o table` | List VNets |

---

## Cost check (end of every session)

```powershell
az resource list -o table
```
Empty output = nothing running = nothing billing. Portal backup: **All resources**.

---

## Git (end of every session)

Commit one session at a time with its log:
- `dev-diary/session-NN.md`
- any changed `.tf` files
- `.terraform.lock.hcl` if it changed

Commit message format: `Session NN: <what you did>`

Never commit: `.terraform/`, `terraform.tfstate`, `terraform.tfstate.backup` (your .gitignore already skips these; tfstate holds your subscription ID).

---

## Recording reminders

- Subscription ID shows in apply/destroy output and resource IDs: blur in the edit
- Email shows top right of the portal: crop or blur
- VS Code full screen: **F11**
