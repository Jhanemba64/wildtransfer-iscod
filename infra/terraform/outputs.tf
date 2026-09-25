output "ipv4" {
  description = "IP publique fixe du serveur"
  value       = aws_eip.server.public_ip
}

output "url" {
  description = "Adresse de l'application"
  value       = "https://${local.domain}"
}

output "ssh" {
  description = "Connexion SSH au serveur"
  value       = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "deploy" {
  description = "Commande de déploiement de l'application, une fois le provisioning terminé"
  value       = "./infra/scripts/deploy.sh ubuntu@${aws_eip.server.public_ip}"
}
