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

  cluster_name = "pcs2023-3"
  domain       = "ace-net.training"
  image        = "Rocky-8"

  instances = {
    mgmt   = { type = "p4-6gb", tags = ["puppet", "mgmt", "nfs"], count = 1 }
    login  = { type = "p8-12gb", tags = ["login", "public", "proxy"], count = 1 }
    node   = { type = "p4-6gb", tags = ["node"], count = 1 }
    node16c = { type = "c16-60gb-392", tags = ["node"], count = 1 }
    gpunode   = { type = "g1-8gb-c4-22gb", tags = ["node"], count = 16 }
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

  public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5wTADe54hOIewOERz1cOp1LzF5UmbyCl+9hyhzNZ3T cgeroux@sol"]
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
