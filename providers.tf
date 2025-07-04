# Configuration du provider AWS
provider "aws" {
  region = var.aws_region
  # Les credentials AWS seront lues depuis variables 
  # AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY
}

# Configuration du provider GCP
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
  # Les credentials GCP seront lues depuis GOOGLE_APPLICATION_CREDENTIALS
  # ou via gcloud auth application-default login
}