# Session 19 — 2026-11-23

**Goal (one thing):** Add a Basic container registry with Terraform and have Azure build the API into an image tagged `v1`, with no Docker on the laptop
**Time:** early afternoon, about 1:15 to 1:32 PM (recording paused during apply)
**Recording:** webcam ✅ · screen ✅

## What I did
- Added `registry.tf` (Basic Azure Container Registry, admin user off, behind the `enable_registry` switch) and `today.auto.tfvars` (turns today's switches on so plain plan/apply picks them up)
- Added `api\Dockerfile` (python:3.13-slim) and `api\.dockerignore`
- `git status --short`: `today.auto.tfvars` not listed, so the `.tfvars` rule keeps it out of the public repo ✅
- `terraform validate`: success. `terraform plan`: 1 to add. `terraform apply`: registry up in about a minute
- `az acr build -r $acr -t rag-api:v1 --build-arg APP_VERSION=v1 api`: ACR Tasks zipped the folder, built and pushed the image in Azure. Run ca1 successful after 38 seconds ✅
- Checks: tag `v1` present; registry `Basic`, admin user `False`; `az acr task list-runs` shows one Succeeded run ✅
- Portal: Repositories > rag-api > v1, showed the `sha256:` digest
- Cost check: 4 resources in rg-rag-app-eus (Log Analytics, Foundry, Cosmos DB, registry)

## What broke
- Nothing
- Docker is installed on my laptop, but this session didn't use it on purpose: the build ran in Azure

## What I learned
- ACR Tasks quick builds (`az acr build`) run a Docker build in Azure and push the result, so a laptop or pipeline doesn't need Docker at all
- A tag (`v1`) is a label that can be moved to another image; the digest (`sha256:...`) is the image's fixed fingerprint
- Admin user off means no shared username and password on the registry. Container Apps will pull with a managed identity (AcrPull role) in Session 20
- A `*.auto.tfvars` file is read by Terraform automatically, which keeps a plain apply from switching the registry off and deleting it

## Azure cost check
- Resources left running on purpose for Session 20: Log Analytics, Foundry, Cosmos DB free tier, and the registry (the one that costs while idle, about a cent an hour)
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about 2 cents (registry time plus a cent for the build; list-price estimate)

## Next session's goal
- Deploy the v1 image to Azure Container Apps, pulling from the registry with a managed identity
