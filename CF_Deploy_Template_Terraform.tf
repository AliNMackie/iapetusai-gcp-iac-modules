# Terraform Module: Secure Cloud Function Deployment Standard (CF_DEPLOY)
# Purpose: Deploys a Cloud Function (Gen 2) with least-privilege service account,
# secure secret injection, and all necessary IAM roles for a robust deployment.

# --- Input Variables ---
variable "function_name" {
  description = "The name for the Cloud Function (e.g., 'lead-capture-handler')."
  type        = string
}

variable "source_bucket_name" {
  description = "The globally unique name for the GCS bucket to store function code."
  type        = string
}

variable "entry_point" {
  description = "The name of the function inside your main.py (e.g., 'cf_lead_capture_handler')."
  type        = string
}

variable "secret_name" {
  description = "The name of the secret in Google Secret Manager to grant access to (e.g., 'crm-api-key')."
  type        = string
}

variable "project_id" {
  description = "The GCP Project ID to deploy resources into."
  type        = string
}

# --- Dynamic Project Data ---
data "google_project" "current" {
  project_id = var.project_id
}

locals {
  # Use the dynamic project number for Service Agent emails
  project_number       = data.google_project.current.number
  cloud_build_sa_email = "${local.project_number}@cloudbuild.gserviceaccount.com"
  # This is the Cloud Run Service Agent, which manages the function's execution environment
  cloud_run_service_agent_email = "service-${local.project_number}@serverless-robot-prod.iam.gserviceaccount.com"
  # Targets the Default Compute Engine SA (needed for the build fix)
  compute_engine_sa_email = "${local.project_number}-compute@developer.gserviceaccount.com" 
}

# --- CRITICAL: 0. Explicit API Enablement (For Repeatability) ---
# These blocks ensure all required APIs are enabled for every environment (dev/stage/prod)
resource "google_project_service" "secretmanager_api" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# --- 1. Cloud Function Deployment ---
resource "google_cloudfunctions2_function" "cf_standard" {
  name        = var.function_name
  project     = var.project_id
  location    = "europe-west2"
  description = "Standard secure function deployed via CF_DEPLOY module."

  build_config {
    runtime     = "python311"
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = "source.zip"
      }
    }
  }

  service_config {
    max_instance_count = 5
    available_memory   = "256Mi"
    timeout_seconds    = 60

    # CRITICAL: Function must run as its own dedicated Service Account (Least Privilege)
    service_account_email = google_service_account.function_sa.email

    # Grant the function access to pull the secret from Secret Manager
    # This securely injects the API key into the function's environment (Section 3.5.1)
    secret_environment_variables {
      key        = "CRM_API_KEY"
      secret     = var.secret_name
      project_id = var.project_id
      version    = "latest"
    }
    
    # Allows external Dialogflow webhooks to reach the function
    ingress_settings = "ALLOW_ALL" 
  }

  # Dependencies ensure the IAM roles and source code are ready before deployment starts
  depends_on = [
    google_storage_bucket_object.source_zip,
    google_storage_bucket_iam_member.cloudbuild_gcs_reader,
    google_project_iam_member.cloudbuild_artifact_registry_writer, # Dependency on Fix 9
    google_project_iam_member.compute_sa_artifact_registry_writer  # Dependency on Fix 10
  ]
}

# --- 2. Function's Dedicated Service Account (SA) ---
# Enforces Principle of Least Privilege (Section 3.3)
resource "google_service_account" "function_sa" {
  account_id   = "${var.function_name}-sa"
  display_name = "SA for ${var.function_name}"
  project      = var.project_id
}

# --- 3. GCS Source Bucket ---
resource "google_storage_bucket" "source_bucket" {
  name                          = var.source_bucket_name
  project                       = var.project_id
  location                      = "EUROPE-WEST2"
  uniform_bucket_level_access = true
  storage_class                 = "STANDARD"
}

# --- 4. Upload Source Code Zip ---
resource "google_storage_bucket_object" "source_zip" {
  name   = "source.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = "source.zip" # Path to your local zip file (must exist!)
}


# --- 5. IAM: Function SA -> Secret Manager Access (Allows Runtime Access) ---
# CRITICAL: This is what allows the Cloud Function to fetch the CRM_API_KEY at runtime.
resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  project   = var.project_id
  secret_id = var.secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
  # DEPENDS on the secret being created first
  depends_on = [google_secret_manager_secret.crm_api_key_secret] 
}

# --- 6. IAM: Cloud Build Read Access to GCS Source ---
# CRITICAL: Allows the deployment process (Cloud Build SA) to read the source code from GCS.
resource "google_storage_bucket_iam_member" "cloudbuild_gcs_reader" {
  bucket = google_storage_bucket.source_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.cloud_build_sa_email}"
}

# --- 7. IAM: Cloud Build SA -> Function SA (Allows Deployment) ---
# Allows Cloud Build (the deployer) to use the new Service Account (function_sa)
resource "google_service_account_iam_member" "cf_sa_user" {
  service_account_id = google_service_account.function_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloud_build_sa_email}"
}

# --- 8. IAM: Cloud Run Service Agent -> Function SA (Allows Execution) ---
# Allows the underlying Cloud Run/Serverless environment to run the function as its SA
resource "google_service_account_iam_member" "cf_run_sa_user" {
  service_account_id = google_service_account.function_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloud_run_service_agent_email}"
}

# --- 9. FIX: IAM for Artifact Registry (Cloud Build SA) ---
# Grants the Artifact Registry Writer role to the *dedicated* Cloud Build SA.
resource "google_project_iam_member" "cloudbuild_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.cloud_build_sa_email}"
  depends_on = [google_project_service.artifactregistry_api]
}

# --- 10. FIX: IAM for Artifact Registry (Compute Engine SA) ---
# This targets the Default Compute Engine SA, resolving the build failure error code 13.
resource "google_project_iam_member" "compute_sa_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.compute_engine_sa_email}"
  depends_on = [google_project_service.artifactregistry_api]
}
# --- 11. CRITICAL ADDITION: Secret Resource Creation (Final Syntax) ---
# This block ensures the secret exists before we try to set IAM policy on it (Fixes 404 error).
resource "google_secret_manager_secret" "crm_api_key_secret" {
  project   = var.project_id
  secret_id = var.secret_name
  
  replication {
    # Using 'user_managed' replication to bypass the syntax error with 'automatic' 
    # and explicitly define the secure region (enterprise standard: Section 3.2).
    user_managed {
      replicas {
        location = "europe-west2"
      }
    }
  }
  # Ensures the Secret Manager API is enabled first
  depends_on = [google_project_service.secretmanager_api]
}