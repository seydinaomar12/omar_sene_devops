variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "gcp_project_id" {
  description = "projet-seydina-omar-devops"
  type        = string
}

variable "gcp_region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "gcp_zone" {
  description = "Zone GCP"
  type        = string
  default     = "europe-west1-b"
}

variable "instance_name_prefix" {
  description = "Préfixe pour les noms d'instances"
  type        = string
  default     = "terraform-demo"
}

variable "user_name" {
  description = "Nom de l'utilisateur à afficher sur la page web"
  type        = string
  default     = "omar-sene"
}

variable "run_ansible" {
  description = "Exécuter Ansible après la création des instances"
  type        = bool
  default     = true
}
variable "enable_monitoring" {
  description = "Activer le monitoring avec Prometheus et Grafana"
  type        = bool
  default     = true
}
variable "monitoring_ip" {
  description = "IP du serveur de monitoring"
  type        = string
  default     = "3.239.15.139"  # ou une IP par défaut
}