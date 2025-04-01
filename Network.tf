# ----- Настройка сети -----
resource "yandex_vpc_network" "diplom-net" {
  name = "diplom-net"
}

# ----- Таблица маршрутизации -----
resource "yandex_vpc_route_table" "rt" {
  name       = "diplom-route-table"
  network_id = yandex_vpc_network.diplom-net.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# ----- NAT-шлюз -----
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "diplom-gateway"
  shared_egress_gateway {}
}

#  Public subnet for bastion

resource "yandex_vpc_subnet" "public-subnet-a" {
  name = "public-subnet-a"

  v4_cidr_blocks = ["192.168.10.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diplom-net.id
}

# ----- Приватные подсети -----
resource "yandex_vpc_subnet" "private-subnet-web1" {
  name           = "private-subnet-web1"
  v4_cidr_blocks = ["192.168.20.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diplom-net.id
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "private-subnet-web2" {
  name           = "private-subnet-web2"
  v4_cidr_blocks = ["192.168.30.0/24"]
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.diplom-net.id
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "private-subnet-services" {
  name           = "private-subnet-services"
  v4_cidr_blocks = ["192.168.40.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diplom-net.id
  route_table_id = yandex_vpc_route_table.rt.id
}

# ----- Группы безопасности -----
resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion"
  description = "Public Group Bastion"
  network_id  = yandex_vpc_network.diplom-net.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----Security SSH Traffic-----
resource "yandex_vpc_security_group" "security-ssh-traffic" {
  name        = "security-ssh-traffic"
  network_id  = yandex_vpc_network.diplom-net.id
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.20.0/24", "192.168.30.0/24", "192.168.40.0/24"]
  }
}


# Elastic
resource "yandex_vpc_security_group" "elastic" {
  name        = "elastic"
  description = "Private Group Elasticsearch"
  network_id  = yandex_vpc_network.diplom-net.id

  ingress {
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.kibana.id
    port              = 9200
  }

  ingress {
    protocol          = "TCP"
    description       = "Rule for web"
    security_group_id = yandex_vpc_security_group.private-sg.id
    port              = 9200
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Zabbix-server
resource "yandex_vpc_security_group" "zabbix" {
  name        = "pub-zabbix"
  description = "Public Group Zabbix"
  network_id  = yandex_vpc_network.diplom-net.id

  ingress {
    protocol       = "TCP"
    description    = "allow HTTP protocol"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "allow 10050 and 10051"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 10050
    to_port        = 10051
  }

  ingress {
    protocol       = "TCP"
    description    = "allow 5432 psql"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5432
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Kibana
resource "yandex_vpc_security_group" "kibana" {
  name        = "kibana"
  description = "Public Group Kibana"
  network_id  = yandex_vpc_network.diplom-net.id
  

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "private-sg" {
  name       = "private-sg"
  description = "Security group for private network"
  network_id = yandex_vpc_network.diplom-net.id

  ingress {
    protocol = "TCP"

    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.20.0/24", "192.168.30.0/24", "192.168.40.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "load-balancer-sg" {
  name       = "load-balancer-sg"
  network_id = yandex_vpc_network.diplom-net.id

  ingress {
    protocol          = "ANY"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}