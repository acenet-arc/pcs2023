terraform {
  required_version = ">= 1.2.1"
}

variable "pool" {
  description = "Slurm pool of compute nodes"
  default = []
}

module "openstack" {
  source         = "./openstack"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "12.4.0"

  cluster_name = "pcs2023"
  domain       = "ace-net.training"
  image        = "Rocky-8"

  instances = {
    mgmt   = { type = "p4-6gb", tags = ["puppet", "mgmt", "nfs"], count = 1 }
    login  = { type = "p8-12gb", tags = ["login", "public", "proxy"], count = 1 }
    node   = { type = "p4-6gb", tags = ["node"], count = 16 }
    node16 = { type = "c16-60gb-392", tags = ["node"], count = 1 }
    gpunode   = { type = "g1-8gb-c4-22gb", tags = ["node"], count = 1 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = {
    nfs = {
      home     = { size = 100 }
      project  = { size = 50 }
      scratch  = { size = 50 }
    }
  }

  public_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQClvBnQRC2Tesx+357C+RjpN1MxPgbwLrLxSidjl3tInYUVGfwBuNOZ5A+EJBImoCDLZDruioKu2hCM+aR7BlqQQG63wIzIIijTyJsJypmPIH2YpdMPmxY8ntX5ju/mq/F1IBs9hFYWQ5FNwblGl6mxI5HjYcHtNGmfFF0uxmYaTJku+wY0N/GMiTru5XEFVwXh11bg/INaH4GQjbjIn5nlaHBqc2zISqdJ/gc0hPJRnUgYrP0rtlXF3uhQh8Xepu8sM+pcOhqR76ZaJ81SOmDI/zvaejdDjdSEox1TSWNgXSSB6EIdD1lYEEXSWs/d4cIUE7k1X+/j5oVdtBgrBlvB5RNDkBF5m66hh+IgTgFrdX3P1XgSuqZqHy5Zh1Th9di6MqNUt+Y0kd/4Wm54yG1HPbGNKH2mpncWxWa4C2ORkk1TMftONrLvXWbvJVmRLV16koYHE0tezITsrHcivfIx++wOU5eBrcA5mJJknU38vaC135zJ/e7qjTJ2rj9Ja7euqPa34oRzMjMuhJTy3mB9zDuen+gr9XumW/OnUdpqnwg/IlwmuuugWV2KQ7uDFjuBB+ho3ycMCv5zZhmAX7s9Sg3NDoNze88qZG0cDzVWvOBdDe+U+0TTSB+a5TdhzYlX4gEx01Z/UH84SfJGrpxpcEoVxKQB9zsGuNy2ina/Hw== ubuntu@castle-manager"]
  generate_ssh_key = true

  nb_users = 100
  # Shared password, randomly chosen if blank
  guest_passwd = ""
  
  hieradata="profile::cvmfs::client::repositories: ['cvmfs-config.computecanada.ca', 'soft.computecanada.ca','restricted.computecanada.ca']"
}

output "accounts" {
  value = module.openstack.accounts
}

output "public_ip" {
  value = module.openstack.public_ip
}

# Uncomment to register your domain name with CloudFlare
module "dns" {
  source           = "./dns/cloudflare"
  email            = "chris.geroux@ace-net.ca"
  name             = module.openstack.cluster_name
  domain           = module.openstack.domain
  public_instances = module.openstack.public_instances
  ssh_private_key  = module.openstack.ssh_private_key
  sudoer_username  = module.openstack.accounts.sudoer.username
}

## Uncomment to register your domain name with Google Cloud
# module "dns" {
#   source           = "./dns/gcloud"
#   email            = "you@example.com"
#   project          = "your-project-id"
#   zone_name        = "you-zone-name"
#   name             = module.openstack.cluster_name
#   domain           = module.openstack.domain
#   public_instances = module.openstack.public_instances
#   ssh_private_key  = module.openstack.ssh_private_key
#   sudoer_username  = module.openstack.accounts.sudoer.username
# }

output "hostnames" {
  value = module.dns.hostnames
}
