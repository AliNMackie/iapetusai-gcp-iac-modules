# --- File: provider.tf (CORRECTED - COPY THIS) ---

provider "google" {
  project = var.project_id
  region  = "europe-west2"
}

provider "google-beta" {
  project = var.project_id
  region  = "europe-west2"
  alias   = "beta"

  # --- THIS IS THE FIX ---
  # Tells the provider to use your 'project_id' for API
  # quota and billing, which is required by the
  # Discovery Engine API when using user (ADC) credentials.
  user_project_override = true
}