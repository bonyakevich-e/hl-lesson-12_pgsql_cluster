# получаем id образа ubuntu 24.04
data "yandex_compute_image" "ubuntu2404" {
  family = "ubuntu-2404-lts-oslogin"
}

# получаем id дефолтной network
data "yandex_vpc_network" "default" {
  name = "default"
}

# создаем дополнительный диск, который используется как iscsi share
resource "yandex_compute_disk" "shared_disk" {
  name = "shared-disk"
  type = "network-hdd"
  size = "5"
}

# создаем подсеть
resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet01"
  network_id     = data.yandex_vpc_network.default.network_id
  v4_cidr_blocks = ["10.16.0.0/24"]
}

# создаем сервера под базу данных
resource "yandex_compute_instance" "database" {
  count    = var.database_size
  name     = "${var.database_name}${count.index + 1}"
  hostname = "${var.database_name}${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-${var.database_name}${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# создаем сервера под etcd кластер
resource "yandex_compute_instance" "etcd" {
  count    = 3
  name     = "etcd${count.index + 1}"
  hostname = "etcd${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-etcd${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# создаем инстансы под backend
resource "yandex_compute_instance" "backend" {
  count    = var.backend_size
  name     = "${var.backend_name}${count.index + 1}"
  hostname = "${var.backend_name}${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-${var.backend_name}${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# создаем inventory файл для Ansible
resource "local_file" "inventory" {
  filename        = "./hosts"
  file_permission = "0644"
  content         = <<EOT
[database]
%{for vm in yandex_compute_instance.database.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor}

[backend]
%{for vm in yandex_compute_instance.backend.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}

[etcd]
%{for vm in yandex_compute_instance.etcd.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}

EOT
}

# создаем Ansible playbook
resource "local_file" "playbook_yml" {
  filename        = "./playbook.yml"
  file_permission = "0644"
  content = templatefile("playbook.tmpl.yml", {
    remote_user = var.system_user,
    database    = yandex_compute_instance.database[*],
    backend     = yandex_compute_instance.backend[*],
    etcd        = yandex_compute_instance.etcd[*]
  })
}

resource "local_file" "etcd_conf_etcd1" {
  filename        = "templates/etcd/etcd.conf_etcd1"
  file_permission = "0644"
  content = templatefile("templates/etcd/etcd.conf_etcd1.tmpl", {
    etcd1 = yandex_compute_instance.etcd[0],
    etcd2 = yandex_compute_instance.etcd[1],
    etcd3 = yandex_compute_instance.etcd[2]
  })
}

resource "local_file" "etcd_conf_etcd2" {
  filename        = "templates/etcd/etcd.conf_etcd2"
  file_permission = "0644"
  content = templatefile("templates/etcd/etcd.conf_etcd2.tmpl", {
    etcd1 = yandex_compute_instance.etcd[0],
    etcd2 = yandex_compute_instance.etcd[1],
    etcd3 = yandex_compute_instance.etcd[2]
  })
}

resource "local_file" "etcd_conf_etcd3" {
  filename        = "templates/etcd/etcd.conf_etcd3"
  file_permission = "0644"
  content = templatefile("templates/etcd/etcd.conf_etcd3.tmpl", {
    etcd1 = yandex_compute_instance.etcd[0],
    etcd2 = yandex_compute_instance.etcd[1],
    etcd3 = yandex_compute_instance.etcd[2]
  })
}

resource "local_file" "patroni_yml_database1" {
  filename        = "templates/database/patroni.yml_database1"
  file_permission = "0644"
  content = templatefile("templates/database/patroni.yml_database1.tmpl", {
    etcd1     = yandex_compute_instance.etcd[0],
    etcd2     = yandex_compute_instance.etcd[1],
    etcd3     = yandex_compute_instance.etcd[2],
    database1 = yandex_compute_instance.database[0],
    database2 = yandex_compute_instance.database[1]
  })
}

resource "local_file" "patroni_yml_database2" {
  filename        = "templates/database/patroni.yml_database2"
  file_permission = "0644"
  content = templatefile("templates/database/patroni.yml_database2.tmpl", {
    etcd1     = yandex_compute_instance.etcd[0],
    etcd2     = yandex_compute_instance.etcd[1],
    etcd3     = yandex_compute_instance.etcd[2],
    database1 = yandex_compute_instance.database[0],
    database2 = yandex_compute_instance.database[1]
  })
}

