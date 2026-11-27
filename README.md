# Multi-VM Dynamic YAML Compute Infrastructure (Testing Repository)

This repository demonstrates dynamic YAML-driven GCP Compute Engine VM provisioning (1 VM per environment: `dev`, `uat`, `prod`) using the **`default` VPC and `default` subnet**, integrated with the unified centralized CI/CD pipeline hosted at **[yuva-cloud-devops/terraform-github-actions-templates](https://github.com/yuva-cloud-devops/terraform-github-actions-templates)**.

---

## 1. Directory Structure

```
terraform-github-actions-templates-testing/
│
├── .github/
│   ├── pull_request_template.md   # PR template with deployment_request & configuration
│   └── workflows/
│       └── terraform.yml          # Unified CI/CD workflow (CTP) calling terraform-pipeline.yml@main
│
├── compute-infrastructure/
│   ├── versions.tf                # Google provider & empty GCS backend
│   ├── variables.tf               # Region, project_id, environment, config_file inputs
│   ├── main.tf                    # Dynamic block YAML VM engine (uses default VPC & subnet)
│   └── outputs.tf                 # Public & private IP summary
│
├── environments/
│   ├── dev/
│   │   └── compute.yaml           # DEV VM definition (Public IP enabled)
│   ├── uat/
│   │   └── compute.yaml           # UAT VM definition (Private IP only)
│   └── prod/
│       └── compute.yaml           # PROD VM definition (Private IP only)
│
└── schema/
    └── compute.schema.json        # JSON Schema matched automatically from configuration: compute.yaml
```

---

## 2. Dynamic Blocks Architecture (`compute-infrastructure/main.tf`)

VM definitions live in `environments/<env>/compute.yaml` and are decoded via Terraform's `yamldecode()`.
* **Networking**: Uses the GCP `default` VPC (`network = "default"`) and `default` subnet (`subnetwork = null`).
* **Public vs. Private IP (`dynamic "access_config"`)**:
  * **`enable_public_ip: true`** (`dev`): Creates an `access_config` block (ephemeral or static public IP).
  * **`enable_public_ip: false`** (`uat`, `prod`): Omits `access_config` completely, keeping the VM strictly internal/private.

---

## 3. End-to-End Pipeline Flow (Every Step)

### Pull Request (`pull_request` to `main`)
1. Open a PR using `.github/pull_request_template.md`:
   ```yaml
   deployment_request:
     infrastructure:
       - compute-infrastructure
     environment: dev
     configuration: compute.yaml
     description: "Deploy Compute Infrastructure (Dynamic YAML VMs)"
   ```
2. **`CTP / Step 1 - Parse PR & Config Metadata`**: Extracts `env` (`dev`), `config_file` (`compute.yaml`), and dependency-sorted `stacks` (`["compute-infrastructure"]`).
3. **`CTP / Step 2 - Validate Config & Schema`**: Validates `environments/dev/compute.yaml` against `schema/compute.schema.json`.
4. **Parallel Security Scans**:
   * `CTP / CI - Gitleaks Secret Scan`
   * `CTP / CI - Trivy Vulnerability Scan`
   * `CTP / CI - TFLint Check`
   * `CTP / CI - Checkov Policy Scan`
5. **`CTP / CI - Terraform Format Check`**: Verifies `terraform fmt -check -recursive`.
6. **`CTP / CI - Terraform Validate`**: Runs `terraform init -backend=false` + `terraform validate`.
7. **`CTP / CI - Terraform Plan`**: Authenticates via GCP OIDC, generates `backend.hcl`, runs `terraform init -reconfigure -backend-config=backend.hcl` + `terraform plan`, and exports `tfplan.json`.
8. **`CTP / CI - Post Plan & Audit Comment`**: Aggregates all security reports + `tfplan.json` and posts one sticky PR comment as `github-actions[bot]`.

### Merge to `main` (`push` to `main`)
1. `CTP / Step 1 - Parse PR & Config Metadata` & `CTP / Step 2 - Validate Config & Schema` resolve targets from the merged PR/commit.
2. **`CTP / CD - Terraform Apply (<env>)`**: Enters the GitHub Environment (`dev` = auto-apply; `uat`/`prod` = approval gate), authenticates via OIDC, generates a fresh `backend.hcl`, executes `terraform apply -auto-approve` from the merged `main` code, and exports `outputs.json`.
3. **`CTP / CD - Post Deployment Audit Comment`**: Resolves the merged PR and posts the CD Deployment Audit Report with state paths, deployed VM IPs/outputs, and provenance metadata.

---

## 4. Workflow File (`.github/workflows/terraform.yml`)

```yaml
name: Terraform Pipeline

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read
  issues: write
  pull-requests: write

concurrency:
  group: tf-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  terraform:
    name: CTP
    uses: yuva-cloud-devops/terraform-github-actions-templates/.github/workflows/terraform-pipeline.yml@main
    with:
      cloud_provider: "gcp"
      terraform_version: "1.10.5"
      state_bucket: "yuvaraj-internal-project-dev-tfstate"
      enable_security_scans: true
      templates_ref: "main"
    secrets: inherit
```
