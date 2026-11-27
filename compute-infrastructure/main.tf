locals {
  # Resolve YAML config path: check custom path, then environments/<env>/compute.yaml, then compute.yaml
  config_path = var.config_file != "" ? var.config_file : (
    fileexists("${path.module}/environments/${var.environment}/compute.yaml") ?
    "${path.module}/environments/${var.environment}/compute.yaml" :
    "${path.module}/compute.yaml"
  )

  # Decode YAML file safely
  raw_config = yamldecode(file(local.config_path))

  # Extract instances map from YAML
  instances = { for vm in local.raw_config.instances : vm.name => vm }
}

# -----------------------------------------------------------------------------
# Google Compute Engine Instances (Dynamic Blocks Driven from YAML)
# -----------------------------------------------------------------------------
resource "google_compute_instance" "vm" {
  for_each = local.instances

  name         = each.value.name
  machine_type = try(each.value.machine_type, "e2-medium")
  zone         = try(each.value.zone, "${var.region}-a")
  tags         = try(each.value.tags, ["allow-ssh"])
  labels       = merge(try(each.value.labels, {}), {
    environment = var.environment
    managed_by  = "terraform"
  })

  # Dynamic Boot Disk Block
  boot_disk {
    auto_delete = try(each.value.boot_disk.auto_delete, true)
    initialize_params {
      image = try(each.value.boot_disk.image, "debian-cloud/debian-12")
      size  = try(each.value.boot_disk.size_gb, 20)
      type  = try(each.value.boot_disk.type, "pd-standard")
    }
  }

  # Network Interface with Dynamic Public IP (access_config) block
  network_interface {
    network    = try(each.value.network, "default")
    subnetwork = try(each.value.subnetwork, null)

    # Dynamic access_config block:
    # Included ONLY if enable_public_ip is true.
    # Omitted when enable_public_ip is false, making the VM strictly PRIVATE.
    dynamic "access_config" {
      for_each = try(each.value.enable_public_ip, false) ? [1] : []
      content {
        nat_ip       = try(each.value.static_nat_ip, null)
        network_tier = try(each.value.network_tier, "PREMIUM")
      }
    }
  }

  # Dynamic Service Account Block
  dynamic "service_account" {
    for_each = try(each.value.service_account != null, false) ? [each.value.service_account] : [1]
    content {
      email  = try(each.value.service_account.email, null)
      scopes = try(each.value.service_account.scopes, ["https://www.googleapis.com/auth/cloud-platform"])
    }
  }

  # Metadata startup script
  metadata = merge(
    try(each.value.metadata, {}),
    try(each.value.startup_script, "") != "" ? { "startup-script" = each.value.startup_script } : {}
  )

  allow_stopping_for_update = true
}
