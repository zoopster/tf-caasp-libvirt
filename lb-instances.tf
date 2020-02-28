data "template_file" "lb_repositories" {
  count    = length(var.lb_repositories)
  template = file("cloud-init/repository.tpl")

  vars = {
    repository_url  = element(values(var.lb_repositories), count.index)
    repository_name = element(keys(var.lb_repositories), count.index)
  }
}

data "template_file" "lb_register_scc" {
  template = file("cloud-init/lb-register-scc.tpl")
  count    = var.sle_registry_code == "" ? 0 : 1

  vars = {
    sle_registry_code = var.sle_registry_code
    ha_registry_code  = var.ha_registry_code
  }
}

data "template_file" "lb_register_rmt" {
  template = file("cloud-init/register-rmt.tpl")
  count    = var.rmt_server_name == "" ? 0 : 1

  vars = {
    rmt_server_name = var.rmt_server_name
  }
}

data "template_file" "lb_commands" {
  template = file("cloud-init/lb_commands.tpl")
  count    = join("", var.lb_packages) == "" ? 0 : 1

  vars = {
    lb_packages = join("", var.lb_packages)
  }
}

data "template_file" "haproxy_apiserver_backends_master" {
  count    = var.masters
  template = "server $${fqdn} $${ip}:6443\n"

  vars = {
    fqdn = "${var.stack_name}-master-${count.index}.${var.dns_domain}"
    ip   = cidrhost(var.network_cidr, 128 + count.index)
  }
}

data "template_file" "haproxy_gangway_backends_master" {
  count    = var.masters
  template = "server $${fqdn} $${ip}:32001\n"

  vars = {
    fqdn = "${var.stack_name}-master-${count.index}.${var.dns_domain}"
    ip   = cidrhost(var.network_cidr, 128 + count.index)
  }
}

data "template_file" "haproxy_dex_backends_master" {
  count    = var.masters
  template = "server $${fqdn} $${ip}:32000\n"

  vars = {
    fqdn = "${var.stack_name}-master-${count.index}.${var.dns_domain}"
    ip   = cidrhost(var.network_cidr, 128 + count.index)
  }
}

data "template_file" "lb_haproxy_cfg" {
  template = file("cloud-init/haproxy.cfg.tpl")

  vars = {
    apiserver_backends = join("\n", data.template_file.haproxy_apiserver_backends_master.*.rendered,)
    gangway_backends = join("\n", data.template_file.haproxy_gangway_backends_master.*.rendered,)
    dex_backends = join("\n", data.template_file.haproxy_dex_backends_master.*.rendered,)
  }
}

data "template_file" "lb-cloud-init" {
  template = file("cloud-init/lb.tpl")

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    repositories    = join("\n", data.template_file.lb_repositories.*.rendered)
    lb_register_scc = join("\n", data.template_file.lb_register_scc.*.rendered)
    lb_register_rmt = join("\n", data.template_file.lb_register_rmt.*.rendered)
    lb_commands     = join("\n", data.template_file.lb_commands.*.rendered)
    username        = var.username
    password        = var.password
    ntp_servers     = join("\n", formatlist("    - %s", var.ntp_servers))
  }
}

resource "libvirt_volume" "lb" {
  name           = "${var.stack_name}-lb-volume"
  pool           = var.pool
  size           = var.disk_size
  base_volume_id = libvirt_volume.img.id
}

resource "libvirt_cloudinit_disk" "lb" {
  name = "${var.stack_name}-lb-cloudinit-disk"
  pool = var.pool
  user_data = data.template_file.lb-cloud-init.rendered
}

resource "libvirt_domain" "lb" {
  name      = "${var.stack_name}-lb-domain"
  memory    = var.lb_memory
  vcpu      = var.lb_vcpu
  cloudinit = libvirt_cloudinit_disk.lb.id

  cpu = {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.lb.id
  }

  network_interface {
    network_id     = libvirt_network.network.id
    hostname       = "${var.stack_name}-lb"
    addresses      = [cidrhost(var.network_cidr, 250)]
    wait_for_lease = true
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

resource "null_resource" "lb_wait_cloudinit" {
  depends_on = [libvirt_domain.lb]
  count      = var.lbs

  connection {
    host = element(
      libvirt_domain.lb.*.network_interface.0.addresses.0,
      count.index,
    )
    user     = var.username
    password = var.password
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /dev/null",
    ]
  }
}

resource "null_resource" "lb_push_haproxy_cfg" {
  depends_on = [null_resource.lb_wait_cloudinit]
  count      = var.lbs

  triggers = {
    master_count = var.masters
  }

  connection {
    host = element(
      libvirt_domain.lb.*.network_interface.0.addresses.0,
      count.index,
    )
    user  = var.username
    password = var.password
    type  = "ssh"
    #agent = true
  }

  provisioner "file" {
    content     = data.template_file.lb_haproxy_cfg.rendered
    destination = "/tmp/haproxy.cfg"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg",
      "sudo systemctl enable haproxy && sudo systemctl restart haproxy",
    ]
  }
}
