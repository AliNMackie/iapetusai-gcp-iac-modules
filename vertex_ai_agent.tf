# vertex_ai_agent.tf
# Architecture: Dialogflow CX (Stable)
# Reason: Selected to bypass local ARM64/Rust compilation issues with Reasoning Engine.

# --- 1. Define the Stable Agent (Dialogflow CX) ---
# vertex_ai_agent.tf (The fix for the warning)

resource "google_dialogflow_cx_agent" "chatbot_agent" {
  provider = google-beta
  display_name          = "Industrialized Chatbot Agent"
  location              = "europe-west2"
  default_language_code = "en"
  time_zone             = "Europe/London" 
  
  # 👇 FIX STARTS HERE
  advanced_settings {
    logging_settings {
      enable_stackdriver_logging = true
    }
  }
  # 👆 FIX ENDS HERE

  # ... (rest of the resource)
}

# --- 2. IAM: Allow Agent to Call Cloud Function ---
# This grants the CX Agent permission to invoke your secure Cloud Function.
resource "google_cloudfunctions2_function_iam_member" "agent_invokes_cf" {
  cloud_function = google_cloudfunctions2_function.cf_standard.name
  role           = "roles/cloudfunctions.invoker"
  
  # The member is the Dialogflow Service Agent (P4SA)
  member         = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dialogflow.iam.gserviceaccount.com"
  location       = "europe-west2"
}