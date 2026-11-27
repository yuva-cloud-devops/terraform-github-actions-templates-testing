# Multi-VM Dynamic YAML Compute Infrastructure (Testing Repository)

This repository demonstrates dynamic YAML-driven compute provisioning on Google Cloud Platform (1 VM per environment: `dev`, `uat`, `prod`), integrated with the unified centralized CI/CD pipeline hosted at **[yuva-cloud-devops/terraform-github-actions-templates](https://github.com/yuva-cloud-devops/terraform-github-actions-templates)**.

---

## 1. Directory Structure

```
terraform-github-actions-templates-testing/
│
├── .github/
│   ├── pull_request_template.md   # PR template with deployment_request & configuration
│   └── workflows/
│       └── terraform.yml          # Unified CI/CD workflow calling terraform-pipeline.yml@main
│
├── compute-infrastructure/
│   ├── versions.tf                # Google provider & generic GCS backend
│   ├── variables.tf               # Region, project_id, environment, config_file inputs
│   ├── main.tf                    # Dynamic block YAML VM engine
│   ├── firewall.tf                # Default VPC security rules (Web, Internal, IAP SSH)
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

## 2. How PR Metadata & Schema Validation Work

In your Pull Request body:
```yaml
deployment_request:
  infrastructure:
    - compute-infrastructure
  environment: dev
  configuration: compute.yaml
  description: "Deploy Compute Infrastructure (Dynamic YAML VMs)"
```

1. **`parse-pr-metadata`** extracts `environment` (`dev`), `infrastructure` (`compute-infrastructure`), and `configuration` (`compute.yaml`).
2. **`validate-schema`** strips `.yaml` from `compute.yaml` and automatically validates `environments/dev/compute.yaml` against `schema/compute.schema.json`.
3. **`terraform-plan` / `terraform-apply`** receives `TF_VAR_environment=dev` and `TF_VAR_config_file=.../environments/dev/compute.yaml` and provisions the VM using dynamic `access_config` blocks (`enable_public_ip: true` vs `false`).
