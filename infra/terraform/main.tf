# Ubuntu 22.04 officielle (éditeur Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Pare-feu cloud : seuls SSH, HTTP et HTTPS sont ouverts (doublé par UFW sur le serveur)
resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "WildTransfer : SSH, HTTP, HTTPS"

  dynamic "ingress" {
    for_each = [22, 80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IP publique fixe, connue avant le démarrage : sert aussi au nom <ip>.sslip.io
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = { Name = var.name }
}

locals {
  domain         = var.domain != "" ? var.domain : "${replace(aws_eip.server.public_ip, ".", "-")}.sslip.io"
  staging_domain = "staging.${local.domain}" # environnement de test, même serveur
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # IMDSv2 obligatoire : protège les métadonnées de l'instance
  metadata_options {
    http_tokens = "required"
  }

  # Premier démarrage : cloud-init dépose les scripts d'infra et lance provision.sh
  user_data = templatefile("${path.module}/../cloud-init/user-data.yaml.tftpl", {
    domain         = local.domain
    staging_domain = local.staging_domain
    acme_email     = var.acme_email
    admin_ip       = var.admin_ip
    backup_s3_url  = "https://${aws_s3_bucket.backups.bucket_regional_domain_name}"
    provision_sh   = filebase64("${path.module}/../scripts/provision.sh")
    backup_sh      = filebase64("${path.module}/../scripts/backup.sh")
    nginx_security = filebase64("${path.module}/../config/nginx/security.conf")
    nginx_site     = filebase64("${path.module}/../config/nginx/wildtransfer.conf.template")
    fail2ban_jail  = filebase64("${path.module}/../config/fail2ban/jail.local")
  })

  # user_data ne sert qu'à la création : les évolutions sont appliquées en relançant provision.sh,
  # sans recréer ni redémarrer le serveur
  lifecycle {
    ignore_changes = [user_data]
  }

  tags = { Name = var.name }
}

resource "aws_eip_association" "server" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server.id
}
