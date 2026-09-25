output "ipv4" {
  description = "IP publique fixe du serveur"
  value       = aws_eip.server.public_ip
}

output "url" {
  description = "Adresse de l'application"
  value       = "https://${local.domain}"
}

output "staging_url" {
  description = "Adresse de l'environnement de test"
  value       = "https://${local.staging_domain}"
}

output "backup_s3_url" {
  description = "Destination des sauvegardes hors serveur (dépôt seul, depuis l'IP du serveur)"
  value       = "https://${aws_s3_bucket.backups.bucket_regional_domain_name}"
}

output "ssh" {
  description = "Connexion SSH au serveur"
  value       = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "deploy" {
  description = "Commande de déploiement de l'application, une fois le provisioning terminé"
  value       = "./infra/scripts/deploy.sh ubuntu@${aws_eip.server.public_ip}"
}
