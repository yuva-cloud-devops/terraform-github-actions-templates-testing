output "instances_summary" {
  description = "Summary of provisioned virtual machines"
  value = {
    for k, v in google_compute_instance.vm : k => {
      id          = v.instance_id
      name        = v.name
      zone        = v.zone
      internal_ip = v.network_interface[0].network_ip
      public_ip   = length(v.network_interface[0].access_config) > 0 ? v.network_interface[0].access_config[0].nat_ip : "NONE (Private VM)"
      tags        = v.tags
    }
  }
}
