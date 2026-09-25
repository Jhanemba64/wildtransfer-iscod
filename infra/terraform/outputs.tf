output "ipv4" {
  description = "IP publique : à renseigner dans l'enregistrement DNS A du domaine"
  value       = openstack_compute_instance_v2.server.access_ip_v4
}

output "ssh" {
  description = "Connexion SSH au serveur"
  value       = "ssh ubuntu@${openstack_compute_instance_v2.server.access_ip_v4}"
}

output "deploy" {
  description = "Commande de déploiement de l'application, une fois le provisioning terminé"
  value       = "./infra/scripts/deploy.sh ubuntu@${openstack_compute_instance_v2.server.access_ip_v4}"
}
