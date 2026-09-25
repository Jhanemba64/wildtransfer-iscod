terraform {
  required_version = ">= 1.5"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# OVHcloud Public Cloud repose sur OpenStack.
# Identifiants : charger le fichier openrc.sh téléchargé depuis l'espace client OVH
# (Public Cloud > Users & Roles > Download OpenStack's RC file), qui exporte les variables OS_*.
provider "openstack" {
  auth_url = "https://auth.cloud.ovh.net/v3"
  region   = var.region
}
