variable "name" {
  description = "Nom du serveur et préfixe des ressources"
  type        = string
  default     = "wildtransfer"
}

variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "instance_type" {
  description = "Type d'instance EC2 (t3.small : 2 vCPU, 2 Go RAM)"
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key_path" {
  description = "Clé publique SSH autorisée sur le serveur"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain" {
  description = "Nom de domaine de l'application. Vide : <ip>.sslip.io, utilisable sans DNS"
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "E-mail pour les certificats Let's Encrypt"
  type        = string
}

variable "admin_ip" {
  description = "IP de l'administrateur, jamais bannie par fail2ban (optionnel)"
  type        = string
  default     = ""
}
