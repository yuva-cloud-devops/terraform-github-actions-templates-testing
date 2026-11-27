# Multi-VM Dynamic YAML Compute Infrastructure (Testing Repository)

This repository demonstrates the dynamic YAML-driven compute provisioning model using Terraform on Google Cloud Platform, fully integrated with the centralized CI/CD pipeline hosted at **[yuva-cloud-devops/terraform-github-actions-templates](https://github.com/yuva-cloud-devops/terraform-github-actions-templates)**.

---

## 1. Directory Structure

```
terraform-github-actions-templates-testing/
│
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Calls terraform-continues-integration.yml@main
│       └── cd.yml                 # Calls terraform-continues-provisioning.yml@main
│
├── compute-infrastructure/
│   ├── versions.tf                # Provider & generic backend configuration
│   ├── variables.tf               # Region, project_id, environment inputs
│   ├── main.tf                    # Dynamic block YAML VM engine
│   ├── firewall.tf                # Default VPC security rules (Web, Internal, IAP SSH)
│   ├── outputs.tf                 # Summary of internal and public IP addresses
│   └── environments/
│       └── dev/
│           └── compute.yaml       # VM definitions (Public & Private instances)
│
└── environments/
    ├── dev.yaml                   # High-level deployment metadata
    └── dev/
        └── compute.yaml
```

---

## 2. Dynamic Blocks Architecture (`compute-infrastructure/main.tf`)

VM definitions are declared purely in `environments/dev/compute.yaml` and loaded via Terraform's `yamldecode()` function.

### Private vs. Public IP Handling
The public IP is conditionally provisioned using Terraform's `dynamic "access_config"` block:
```hcl
dynamic "access_config" {
  for_each = try(each.value.enable_public_ip, false) ? [1] : []
  content {
    nat_ip       = try(each.value.static_nat_ip, null)
    network_tier = try(each.value.network_tier, "PREMIUM")
  }
}
```
- **When `enable_public_ip: true`**: Creates an ephemeral or static external IP address (e.g. `dev-web-frontend-01`).
- **When `enable_public_ip: false`**: The `access_config` block is completely omitted, resulting in a strictly **private internal VM** with no public IP surface (e.g. `dev-app-backend-01`, `dev-db-postgres-01`).

---

## 3. Network & Security Architecture

- **VPC Network**: Uses the GCP `default` VPC network.
- **Firewall Rules** (`firewall.tf`):
  1. `${var.environment}-allow-web`: Allows HTTP (80) & HTTPS (443) from `0.0.0.0/0` targeting instances tagged with `web`.
  2. `${var.environment}-allow-internal-mesh`: Allows internal communication across `10.128.0.0/9` for instances tagged with `internal-service`.
  3. `${var.environment}-allow-ssh-iap`: Restricts SSH access exclusively through Google Cloud Identity-Aware Proxy (`35.235.240.0/20`) for secure management without exposed SSH ports.

---

## 4. Centralized CI/CD Integration

The local `.github/workflows/ci.yml` and `cd.yml` call the reusable workflows from `yuva-cloud-devops/terraform-github-actions-templates`:

```yaml
# .github/workflows/ci.yml
jobs:
  ci:
    uses: yuva-cloud-devops/terraform-github-actions-templates/.github/workflows/terraform-continues-integration.yml@main
    with:
      terraform_version: "1.10.5"
      cloud_provider: "gcp"
      environment: "dev"
      working_directory: "compute-infrastructure"
      enable_security_scans: true
      templates_ref: "main"
    secrets:
      GCP_WIF_PROVIDER: ${{ secrets.GCP_WIF_PROVIDER }}
      GCP_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      BOT_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
