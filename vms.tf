data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# ----- Bastion VM -----
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public-subnet-a.id
    ip_address = "192.168.10.10"
    nat       = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }
}

# Nginx-1
resource "yandex_compute_instance" "nginx-1" {
  name     = "nginx-1"
  hostname = "nginx-1"
  zone     = "ru-central1-a"

  resources {
    cores         = 2
    core_fraction = 5
    memory        = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.private-subnet-web1.id
    ip_address         = "192.168.20.10"
    security_group_ids  = [yandex_vpc_security_group.private-sg.id]
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }
}

# Nginx-2
resource "yandex_compute_instance" "nginx-2" {
  name     = "nginx-2"
  hostname = "nginx-2"
  zone     = "ru-central1-d"
  platform_id = "standard-v2"

  resources {
    cores         = 2
    core_fraction = 5
    memory        = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.private-subnet-web2.id
    ip_address         = "192.168.30.10"
    security_group_ids  = [yandex_vpc_security_group.private-sg.id]
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }
}

# ----- VM Zabbix -----
resource "yandex_compute_instance" "zabbix" {
  name     = "zabbix"
  hostname = "zabbix-server"
  zone     = "ru-central1-a"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.public-subnet-a.id
    ip_address         = "192.168.10.50"
    nat                 = true
    security_group_ids  = [yandex_vpc_security_group.zabbix.id, yandex_vpc_security_group.private-sg.id]
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }
}

# ----- Elastic VM -----
resource "yandex_compute_instance" "elastic" {
  name     = "elastic"
  hostname = "elastic-server"
  zone     = "ru-central1-b"

  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-subnet-services.id
    ip_address         = "192.168.40.40"
    security_group_ids = [yandex_vpc_security_group.elastic.id, yandex_vpc_security_group.private-sg.id]
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }
}

# ----- Kibana VM -----
resource "yandex_compute_instance" "kibana" {
  name     = "kibana"
  hostname = "kibana-server"
  zone     = "ru-central1-a"

  resources {
    cores         = 4
    memory        = 6
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public-subnet-a.id
    ip_address         = "192.168.10.60"
    nat       = true
    security_group_ids = [yandex_vpc_security_group.kibana.id, yandex_vpc_security_group.private-sg.id]
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }
}

# ----- Балансировщик нагрузки -----
resource "yandex_alb_load_balancer" "my-balancer" {
  name              = "my-balancer"
  network_id        = yandex_vpc_network.diplom-net.id
  security_group_ids = [yandex_vpc_security_group.load-balancer-sg.id, yandex_vpc_security_group.private-sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public-subnet-a.id
    }
  }

  listener {
    name = "listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http-router.id
      }
    }
  }
}

# ----- HTTP router -----
resource "yandex_alb_http_router" "http-router" {
  name          = "http-router"
  labels        = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "my-virtual-host" {
  name                    = "my-virtual-host"
  http_router_id          = yandex_alb_http_router.http-router.id
  route {
    name                  = "my-way"
    http_route {
      http_route_action {
        backend_group_id  = yandex_alb_backend_group.backend-group.id
        timeout           = "60s"
      }
    }
  }
}

# ----- Backend -----
resource "yandex_alb_backend_group" "backend-group" {
  name                     = "backend-group"

  http_backend {
    name                   = "backend"
    weight                 = 1
    port                   = 80
    target_group_ids       = [yandex_alb_target_group.target-group.id]
    load_balancing_config {
      panic_threshold      = 90
    }
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15 
      http_healthcheck {
        path               = "/"
      }
    }
  }
}


# ----- Target Group -----
resource "yandex_alb_target_group" "target-group" {
  name = "target-group"

  target {
    subnet_id = yandex_vpc_subnet.private-subnet-web1.id
    ip_address = yandex_compute_instance.nginx-1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.private-subnet-web2.id
    ip_address   = yandex_compute_instance.nginx-2.network_interface.0.ip_address
  }
}