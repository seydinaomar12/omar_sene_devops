# Data source pour récupérer l'AMI automatiquement
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Ressources AWS
# VPC pour AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.instance_name_prefix}-vpc"
  }
}

# Subnet public pour AWS
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.instance_name_prefix}-public-subnet"
  }
}

# Internet Gateway pour AWS
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.instance_name_prefix}-igw"
  }
}

# Route table pour AWS
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.instance_name_prefix}-public-rt"
  }
}

# Association route table avec subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group pour AWS
resource "aws_security_group" "web" {
  name        = "${var.instance_name_prefix}-web-sg"
  description = "Security group pour les instances web"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name_prefix}-web-sg"
  }
}

# Key Pair pour AWS - CORRIGÉ pour Windows
resource "aws_key_pair" "main" {
  key_name   = "${var.instance_name_prefix}-key"
  public_key = file("${pathexpand("~/.ssh/id_rsa.pub")}")
}

# Instance EC2 AWS
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public.id

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Cette page a été générée automatiquement par Omar SENE avec Terraform et configurée avec Ansibl</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "${var.instance_name_prefix}-aws-instance"
  }
}

# Ressources GCP
# Network pour GCP
resource "google_compute_network" "main" {
  name                    = "${var.instance_name_prefix}-network"
  auto_create_subnetworks = false
}

# Subnet pour GCP
resource "google_compute_subnetwork" "main" {
  name          = "${var.instance_name_prefix}-subnet"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id
}

# Firewall rules pour GCP
resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_firewall" "web" {
  name    = "${var.instance_name_prefix}-allow-web"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Instance GCP - CORRIGÉ pour Windows
resource "google_compute_instance" "web" {
  name         = "${var.instance_name_prefix}-gcp-instance"
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.main.name
    subnetwork = google_compute_subnetwork.main.name
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "debian:${file("${pathexpand("~/.ssh/id_rsa.pub")}")}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y apache2
    sudo systemctl start apache2
    sudo systemctl enable apache2
    sudo echo "<h1>Cette page a été générée automatiquement par Omar SENE avec Terraform et configurée avec Ansibl</h1>" > /var/www/html/index.html
  EOF

  tags = ["ssh", "web"]
}

# Outputs
output "aws_instance_public_ip" {
  description = "IP publique de l'instance AWS"
  value       = aws_instance.web.public_ip
}

output "aws_instance_public_dns" {
  description = "DNS public de l'instance AWS"
  value       = aws_instance.web.public_dns
}

output "gcp_instance_external_ip" {
  description = "IP externe de l'instance GCP"
  value       = google_compute_instance.web.network_interface.0.access_config.0.nat_ip
}

output "gcp_instance_internal_ip" {
  description = "IP interne de l'instance GCP"
  value       = google_compute_instance.web.network_interface.0.network_ip
}

# Ajout à votre fichier main.tf existant

# Génération automatique de l'inventaire Ansible
resource "local_file" "ansible_inventory" {
  depends_on = [aws_instance.web, google_compute_instance.web]
  
  content = templatefile("${path.module}/inventory.tpl", {
    aws_ip = aws_instance.web.public_ip
    gcp_ip = google_compute_instance.web.network_interface.0.access_config.0.nat_ip
    ssh_key_path = pathexpand("~/.ssh/id_rsa")
    monitoring_ip = var.monitoring_ip
  })
  
  filename = "${path.module}/inventory.ini"
}

# Provisioner pour exécuter Ansible après la création des instances
resource "null_resource" "ansible_provisioner" {
  depends_on = [local_file.ansible_inventory]
  
  triggers = {
    aws_instance_id = aws_instance.web.id
    gcp_instance_id = google_compute_instance.web.id
    inventory_content = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = "powershell -Command \"Start-Sleep -Seconds 60; ansible-playbook -i inventory.ini playbook.yml\""
    working_dir = path.module
  }
}

# Output pour vérifier l'inventaire généré
output "ansible_inventory_path" {
  description = "Chemin vers le fichier d'inventaire Ansible"
  value       = local_file.ansible_inventory.filename
}

# ========================================
# MONITORING INFRASTRUCTURE - À AJOUTER À LA FIN DE VOTRE main.tf
# ========================================

# Instance de monitoring AWS (Prometheus + Grafana)
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"  # Plus de ressources pour le monitoring
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  subnet_id              = aws_subnet.public.id

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    
    # Installation de Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Création des répertoires
    mkdir -p /opt/monitoring/{prometheus,grafana}
    
    # Configuration Prometheus
    cat > /opt/monitoring/prometheus/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter-aws'
    static_configs:
      - targets: ['${aws_instance.web.private_ip}:9100']
  
  - job_name: 'node-exporter-gcp'
    static_configs:
      - targets: ['${google_compute_instance.web.network_interface.0.network_ip}:9100']
  
  - job_name: 'apache-aws'
    static_configs:
      - targets: ['${aws_instance.web.private_ip}:9117']
  
  - job_name: 'apache-gcp'
    static_configs:
      - targets: ['${google_compute_instance.web.network_interface.0.network_ip}:9117']
EOL

    # Docker Compose pour monitoring
    cat > /opt/monitoring/docker-compose.yml << 'EOL'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
EOL

    # Démarrage des services
    cd /opt/monitoring
    docker-compose up -d
  EOF

  tags = {
    Name = "${var.instance_name_prefix}-monitoring"
  }
}

# Security Group pour le monitoring
resource "aws_security_group" "monitoring" {
  name        = "${var.instance_name_prefix}-monitoring-sg"
  description = "Security group for monitoring server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name_prefix}-monitoring-sg"
  }
}

# Mise à jour du Security Group web pour autoriser les métriques
resource "aws_security_group_rule" "web_monitoring" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9117
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.web.id
}

# Mise à jour des firewall rules GCP pour le monitoring
resource "google_compute_firewall" "monitoring" {
  name    = "${var.instance_name_prefix}-allow-monitoring"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["9100", "9117"]
  }

  source_ranges = ["10.1.0.0/24"]
  target_tags   = ["web"]
}

# Outputs pour le monitoring
output "monitoring_grafana_url" {
  description = "URL d'accès à Grafana"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "monitoring_prometheus_url" {
  description = "URL d'accès à Prometheus"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "monitoring_instance_ip" {
  description = "IP publique de l'instance de monitoring"
  value       = aws_instance.monitoring.public_ip
}