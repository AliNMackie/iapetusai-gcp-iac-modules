# versions.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      # Explicitly pin to the highest available v6 version.
      version = "6.50.0" 
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      # Pin this one too for consistency.
      version = "6.50.0" 
    }
  }
}