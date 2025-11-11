# Terraform Module: Secure Cloud Function Deployment Standard (CF_DEPLOY)
# Purpose: Deploys a new, secure Cloud Function that adheres to IaC standards.
# Enforces least privilege and secure secret retrieval.

variable "function_name" {
  description = "The name for the Cloud Function (e.g., 'lead-capture-handler')."
  type        = string
}

variable "source_bucket" {
  description = "GCS bucket where the zip file containing the function code is stored."
  type        = string
}

variable "entry_point" {
  description = "The name of the function (e.g., 'handle_webhook')."
  type        = string
}

variable "secret_name" {
  description = "The name of the secret in Google Secret Manager to grant access to."
  type        = string
}

variable "project_id" {
  description = "The GCP Project ID to deploy resources into."
  type        = string
}

# 1. Define the Cloud Function Resource
resource "google_cloudfunctions2_function" "cf_standard" {
  name        = var.function_name
  project     = var.project_id  # <--- FIX 1: Added this line
  location    = "europe-west2" 
  description = "Standard secure function deployed via CF_DEPLOY module."
  
  build_config {
    runtime     = "python311"
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = var.source_bucket
        object = "source.zip" 
      }
    }
  }

  service_config {
    max_instance_count = 5 
    available_memory   = "256Mi"
    timeout_seconds    = 60
    
    # CRITICAL: Function must run as its own Service Account (Least Privilege)
    service_account_email = google_service_account.function_sa.email

    # Grant the function access to pull the secret from Secret Manager
    secret_environment_variables {
      key       = "CRM_API_KEY"
      secret    = var.secret_name
      project_id = var.project_id  # <--- FIX 2: Corrected 'project' to 'project_id'
      version   = "latest" 
    }
  }
}
# 2. Define the Dedicated Service Account for this function
# This enforces the Principle of Least Privilege
resource "google_service_account" "function_sa" {
  account_id   = "${var.function_name}-sa"
  display_name = "SA for ${var.function_name}"
  project      = var.project_id
}