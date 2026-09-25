variable "name" {
  description = "Nom du serveur et préfixe des ressources"
  type        = string
  default     = "wildtransfer"
}

variable "region" {
  description = "Région OVHcloud Public Cloud"
  type        = string
  default     = "GRA11"
}

variable "flavor" {
  description = "Gabarit de l'instance (d2-4 : 2 vCPU, 4 Go RAM)"
  type        = string
  default     = "d2-4"
}

variable "image" {
  description = "Image système"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "ssh_public_key_path" {
  description = "Clé publique SSH autorisée sur le serveur"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain" {
  description = "Nom de domaine de l'application (enregistrement DNS A vers l'IP du serveur)"
  type        = string
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
