# -----------------------------------------------------------------------------
# Default VPC Firewall Rules for Compute Instances
# -----------------------------------------------------------------------------

# Allow HTTP/HTTPS traffic to VMs tagged with 'web'
resource "google_compute_firewall" "allow_web" {
  name    = "${var.environment}-allow-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
  description   = "Allow public inbound HTTP and HTTPS to web instances"
}

# Allow internal traffic between default VPC subnets
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal-mesh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.128.0.0/9"]
  target_tags   = ["internal-service"]
  description   = "Allow internal traffic between VMs in default VPC"
}

# Allow SSH via Identity-Aware Proxy (IAP) or direct SSH
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "${var.environment}-allow-ssh-iap"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # 35.235.240.0/20 is Google Cloud IAP IP range for secure private SSH
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-ssh"]
  description   = "Allow SSH access via Google Cloud Identity-Aware Proxy"
}
