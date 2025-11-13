# --- File: terraform.tfvars ---
# Purpose: Sets all values for the variables defined in our .tf files.
# --------------------------------------------------------------------
#
# ⚠️ Security Note: Do NOT check this file into Git if it contains secrets.
# Since we only have project names (not keys), it is safe.

# --- General Project Settings ---
project_id = "iai-chatbot-1" # ❗- (REQUIRED) Fill this in

# --- Cloud Function ("Backend") Settings ---
function_name          = "lead-capture-handler"
source_bucket_name     = "iai-chatbot-1-cf-source-code" # ❗- (REQUIRED) Make this globally unique
entry_point            = "cf_lead_capture_handler"       # Matches the function in main.py

# --- Secret Manager ("Keys") Settings ---
secret_name            = "crm-api-key"

