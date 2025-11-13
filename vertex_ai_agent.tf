# --- File: vertex_ai_agent.tf (Final, Corrected Version) ---
# Purpose: Deploys the Vertex AI Agent (Brain), its Knowledge (Data Store),
#          and grants least-privilege access.

# --- 0. Explicit API Enablement (Ensures Repeatability) ---
resource "google_project_service" "vertex_api" {
  provider           = google-beta.beta
  project            = var.project_id
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dialogflow_api" {
  provider           = google-beta.beta
  project            = var.project_id
  service            = "dialogflow.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "discoveryengine_api" {
  provider           = google-beta.beta
  project            = var.project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

# --- 1. Get the Project's Dialogflow Service Agent (The Agent's "Identity") ---
#
# CORRECTED: This is a "resource" block that finds or creates
# the Google-managed service agent.
resource "google_project_service_identity" "dialogflow_agent" {
  provider = google-beta.beta
  project  = var.project_id
  service  = "dialogflow.googleapis.com"

  depends_on = [google_project_service.dialogflow_api]
}

# --- 2. Define the "Knowledge" (Vertex AI Search Data Store) ---
resource "google_discovery_engine_data_store" "agent_knowledge" {
  provider = google-beta.beta
  project  = var.project_id
  location = "global" 

  data_store_id     = "industrial-chatbot-knowledge" 
  display_name      = "Industrial Chatbot Knowledge"
  industry_vertical = "GENERIC"
  content_config    = "NO_CONTENT" 
  solution_types    = ["SOLUTION_TYPE_CHAT"]

  depends_on = [google_project_service.discoveryengine_api]
}

# --- 3. Define the "Brain" (Vertex AI Conversation Agent) ---
resource "google_dialogflow_cx_agent" "default_agent" {
  provider = google-beta.beta

  display_name          = "Industrialized Chatbot Agent"
  location              = "europe-west2"
  default_language_code = "en"
  time_zone             = "Europe/London"
  
  gen_app_builder_settings {
    engine = google_discovery_engine_data_store.agent_knowledge.id
  }

  depends_on = [
    # CORRECTED: Reference to the resource (no 'data.' prefix)
    google_project_service_identity.dialogflow_agent,
    google_discovery_engine_data_store.agent_knowledge
  ]
}

# --- 4. Grant Agent access to invoke your new Cloud Function ---
resource "google_cloudfunctions2_function_iam_member" "agent_invokes_cf" {
  provider       = google-beta.beta
  project        = var.project_id
  location       = "europe-west2"
  cloud_function = var.function_name
  role           = "roles/cloudfunctions.invoker"

  # CORRECTED: REMOVED 'data.' prefix
  member         = "serviceAccount:${google_project_service_identity.dialogflow_agent.email}"

  # (Assuming 'google_cloudfunctions2_function.cf_standard' is defined in another file)
  # depends_on = [google_cloudfunctions2_function.cf_standard] 
}

# --- 5. Grant Agent access to Firestore (Logging & CMS) ---
resource "google_project_iam_member" "agent_firestore_user" {
  provider = google-beta.beta
  project  = var.project_id
  role     = "roles/datastore.user"

  # CORRECTED: REMOVED 'data.' prefix
  member   = "serviceAccount:${google_project_service_identity.dialogflow_agent.email}"

  depends_on = [google_dialogflow_cx_agent.default_agent]
}

# --- 6. Grant Agent access to read secrets (if needed) ---
resource "google_project_iam_member" "agent_secret_accessor" {
  provider = google-beta.beta
  project  = var.project_id
  role     = "roles/secretmanager.secretAccessor"

  # CORRECTED: REMOVED 'data.' prefix
  member   = "serviceAccount:${google_project_service_identity.dialogflow_agent.email}"

  depends_on = [google_dialogflow_cx_agent.default_agent]
}