resource "openstack_compute_keypair_v2" "admin" {
  name       = "${var.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Pare-feu cloud : seuls SSH, HTTP et HTTPS sont ouverts (doublé par UFW sur le serveur)
resource "openstack_networking_secgroup_v2" "web" {
  name        = "${var.name}-web"
  description = "WildTransfer : SSH, HTTP, HTTPS"
}

resource "openstack_networking_secgroup_rule_v2" "ingress" {
  for_each = toset(["22", "80", "443"])

  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_compute_instance_v2" "server" {
  name            = var.name
  image_name      = var.image
  flavor_name     = var.flavor
  key_pair        = openstack_compute_keypair_v2.admin.name
  security_groups = [openstack_networking_secgroup_v2.web.name]

  network {
    name = "Ext-Net"
  }

  # Premier démarrage : cloud-init dépose les scripts d'infra et lance provision.sh
  user_data = templatefile("${path.module}/../cloud-init/user-data.yaml.tftpl", {
    domain         = var.domain
    acme_email     = var.acme_email
    admin_ip       = var.admin_ip
    provision_sh   = filebase64("${path.module}/../scripts/provision.sh")
    nginx_security = filebase64("${path.module}/../config/nginx/security.conf")
    nginx_site     = filebase64("${path.module}/../config/nginx/wildtransfer.conf.template")
    fail2ban_jail  = filebase64("${path.module}/../config/fail2ban/jail.local")
  })
}
