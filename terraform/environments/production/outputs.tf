output "dns_name_servers" {
  value = module.google-cloud-dns.name_servers
}

output "image_tag" {
  value = var.image_tag
}
