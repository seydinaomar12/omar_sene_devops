terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }

    google = {
      source  = "hashicorp/google"
      version = "6.40.0"
    }
  }

}