terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "aws" {
  region = "eu-west-1" # Spécifiez la région AWS souhaitée
}
# Création d'un groupe de ressources en Europe (West Europe)
resource "azurerm_resource_group" "nginx_rg" {
  name     = "nginx-resource-group"
  location = "West Europe"
}

# Création d'un réseau virtuel
resource "azurerm_virtual_network" "nginx_vnet" {
  name                = "nginx-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nginx_rg.location
  resource_group_name = azurerm_resource_group.nginx_rg.name
}

# Création d'un sous-réseau
resource "azurerm_subnet" "nginx_subnet" {
  name                 = "nginx-subnet"
  resource_group_name  = azurerm_resource_group.nginx_rg.name
  virtual_network_name = azurerm_virtual_network.nginx_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Création d'une passerelle Internet
resource "azurerm_public_ip" "nginx_public_ip" {
  name                = "nginx-public-ip"
  resource_group_name = azurerm_resource_group.nginx_rg.name
  location            = azurerm_resource_group.nginx_rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nginx_nic" {
  name                = "nginx-nic"
  location            = azurerm_resource_group.nginx_rg.location
  resource_group_name = azurerm_resource_group.nginx_rg.name

  ip_configuration {
    name                          = "nginx-nic-config"
    subnet_id                     = azurerm_subnet.nginx_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nginx_public_ip.id
  }
}

# Création d'un groupe de sécurité pour la machine virtuelle
resource "azurerm_network_security_group" "nginx_nsg" {
  name                = "nginx-nsg"
  location            = azurerm_resource_group.nginx_rg.location
  resource_group_name = azurerm_resource_group.nginx_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle ICMP (ping)
  security_rule {
    name                       = "ICMP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle SSH sortante
  security_rule {
    name                       = "SSH-Outbound"
    priority                   = 1004
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Règle HTTP sortante
  security_rule {
    name                       = "HTTP-Outbound"
    priority                   = 1005
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Création d'une machine virtuelle en Europe (West Europe) avec SSH
resource "azurerm_linux_virtual_machine" "nginx_vm" {
  name                            = "nginx-vm"
  resource_group_name             = azurerm_resource_group.nginx_rg.name
  location                        = "West Europe"
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  disable_password_authentication = true # Désactive l'authentification par mot de passe

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Ismail/.ssh/id_rsa.pub") # Spécifiez le chemin vers votre clé publique SSH
  }

  network_interface_ids = [azurerm_network_interface.nginx_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name = "nginxvm" # Nom de la VM

  custom_data = base64encode(<<-EOF
                #cloud-config
                runcmd:
                  - apt-get update
                  - apt-get install -y nginx
                  - systemctl start nginx
                  - systemctl enable nginx
              EOF
  )
}

# Association du groupe de sécurité à l'interface réseau
resource "azurerm_network_interface_security_group_association" "nginx_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nginx_nic.id
  network_security_group_id = azurerm_network_security_group.nginx_nsg.id
}

# Output pour accéder à la machine virtuelle
output "nginx_vm_public_ip" {
  value = azurerm_public_ip.nginx_public_ip.ip_address
}
resource "aws_vpc" "production-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "production-subnet-1" {
  vpc_id            = aws_vpc.production-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
}

resource "aws_internet_gateway" "production-ig" {
  vpc_id = aws_vpc.production-vpc.id
}

resource "aws_route_table" "production-subnet-1-route-table" {
  vpc_id = aws_vpc.production-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.production-ig.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.production-ig.id
  }
}
# Configuration de la table de routage et association au sous-réseau pour le routage du trafic.
resource "aws_route_table_association" "production-subnet-1-association-1" {
  subnet_id      = aws_subnet.production-subnet-1.id
  route_table_id = aws_route_table.production-subnet-1-route-table.id
}
# Création d'un groupe de sécurité pour contrôler l'accès à l'instance EC2 via les ports HTTP et HTTPS.
resource "aws_security_group" "production-security-group" {
  name        = "allow_all"
  description = "Allow All Traffic"
  vpc_id      = aws_vpc.production-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ajustez cette valeur pour restreindre l'accès à certaines adresses IP
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    # ALLOW ALL
  }
}
# Allocation d'une adresse IP élastique et association avec une interface réseau pour l'instance EC2.
resource "aws_network_interface" "production-ec2-1-NI" {
  subnet_id       = aws_subnet.production-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.production-security-group.id]
}

resource "aws_eip" "production-eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.production-ec2-1-NI.id
  associate_with_private_ip = "10.0.1.50"
}
# Définition et recherche de l'AMI Ubuntu la plus récente pour l'instance EC2.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
# Déploiement d'une instance EC2 dans AWS, avec configuration pour l'exécution de Nginx.
resource "aws_instance" "web" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.micro"
  availability_zone = "eu-west-1a"
  network_interface {
    network_interface_id = aws_network_interface.production-ec2-1-NI.id
    device_index         = 0
  }
  user_data = <<-EOF
                #!/bin/bash
                # Mise à jour des paquets et installation de Nginx
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                
                # Ajout de l'utilisateur adminuser
                sudo adduser --disabled-password --gecos "" adminuser
                
                # Configuration des clés SSH pour adminuser
                sudo mkdir /home/adminuser/.ssh
                sudo chmod 700 /home/adminuser/.ssh
                echo 'ssh-rsa AAAA' > /home/adminuser/.ssh/authorized_keys
                sudo chmod 600 /home/adminuser/.ssh/authorized_keys
                sudo chown -R adminuser:adminuser /home/adminuser/.ssh
                EOF
}



# Sortie affichant l'adresse IP publique de l'instance EC2 pour accès externe.
output "public-ip" {
  value = aws_eip.production-eip.public_ip
}
