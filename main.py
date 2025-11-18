# main.py
import json
import os
import functions_framework
from google.cloud import firestore
from thefuzz import process, fuzz

# Initialize Firestore client globally
db = firestore.Client()


def log_conversation(req_json: dict):
    """
    MANDATORY AUDIT LOG: Logs the incoming full request to the chat-logs
    collection for compliance and KPI tracking (Section 3.5.2).
    """
    # This ensures the bot provides an immutable, auditable trail (Section 6.2).
    # The Function's Service Account must have 'create' access to /chat-logs/
    try:
        log_data = {
            "timestamp": firestore.SERVER_TIMESTAMP,
            "session_id": req_json.get("sessionInfo", {}).get("session", "UNKNOWN"),
            "intent_display_name": req_json.get("intentInfo", {}).get("displayName", "N/A"),
            "user_text": req_json.get("text", "N/A"),
            "parameters": req_json.get("sessionInfo", {}).get("parameters", {}),
        }
        db.collection("chat-logs").add(log_data)
        print("Audit: Successfully logged conversation to Firestore.")
    except Exception as e:
        # CRITICAL: Do not fail the user response if logging fails. Log the error (Section 4.2).
        print(f"CRITICAL LOGGING FAILURE: {e}")


def handle_knowledge_fallback(user_query: str) -> str | None:
    """
    Queries the Firestore /knowledge-base collection to find a semantic match.
    This is the core of the "Client-Managed CMS" (Section 6.1.1).
    """
    print(f"Attempting knowledge fallback for query: {user_query}")
    
    # This query works because the Function's Service Account has
    # read-only access per Firestore Security Rule 2B (Appendix C [cite: 285]).
    kb_ref = db.collection("knowledge-base")
    all_docs = kb_ref.stream()

    choices = {}
    for doc in all_docs:
        data = doc.to_dict()
        if "question" in data and "answer" in data:
            choices[data["question"]] = data["answer"]

    if not choices:
        print("Knowledge base is empty. Skipping fallback.")
        return None

    # Use thefuzz for approximate string matching on the knowledge base
    best_match = process.extractOne(user_query, choices.keys(), scorer=fuzz.token_sort_ratio)
    
    if best_match:
        match_text, score = best_match
        
        # Set a confidence threshold (e.g., 85)
        print(f"Best match: '{match_text}' with score {score}")
        if score > 85:
            print("Match found. Returning answer from CMS.")
            return choices[match_text] # Return the corresponding answer
    
    print("No confident match found in knowledge base.")
    return None


def send_handoff_notification(full_name: str, email: str, context: str) -> bool:
    """
    Sends a secure notification (e.g., email or Zendesk ticket) to the sales team,
    implementing the Human Handoff Strategy (Section 3.6).
    """
    # CRITICAL: Key is retrieved from environment variable
    # injected securely by Cloud Functions from Google Secret Manager (Section 3.5.1 [cite: 110]).
    email_api_key = os.environ.get('CRM_API_KEY')
    
    if not email_api_key:
        print("ERROR: CRM_API_KEY is missing. Handoff failed.")
        return False
        
    print(f"--- ATTEMPTING SECURE HANDOFF ---")
    print(f"Key used: {email_api_key[:5]}... (from Secret Manager)") 
    print(f"TO: sales@iapetusai.com (Simulated)")
    print(f"SUBJECT: NEW High-Value Handoff - {full_name}")
    print(f"BODY:\n Email: {email}\n Context: {context}\n")
    print("--- EMAIL SUCCESSFULLY SENT (SIMULATED) ---")
    
    return True


@functions_framework.http
def cf_lead_capture_handler(request):
    """
    Main webhook entry point.
    Handles intent routing, parameter collection, and fallback.
    """
    try:
        req = request.get_json()
        
        # --- PHASE 1: MANDATORY AUDIT LOGGING ---
        # This is the crucial first step for compliance (Section 3.5.2 ).
        log_conversation(req)
        
        # Get the current intent and user query
        intent_name = req.get("intentInfo", {}).get("displayName", "")
        user_query = req.get("text", "")
        response_text = None

        # --- PHASE 2: INTENT ROUTING ---
        
        if intent_name == "Lead Capture & Qualification":
            print("Handling intent: sales.lead_capture_start")
            session_params = req.get("sessionInfo", {}).get("parameters", {})
            name = session_params.get("full_name", "Valued Prospect")
            
            # Initiate the CRM/API call for the lead captured
            # (Sprint 2 Task [cite: 163])
            send_handoff_notification(
                name, 
                session_params.get("email_address", "N/A"), 
                "Lead captured via intent: Lead Capture & Qualification"
            )
            
            response_text = f"Thank you, {name}. Your request has been securely logged. A member of our advisory team will be in contact with you shortly."

        elif intent_name == "handoff.request":
            print("Processing human handoff request...")
            session_params = req.get("sessionInfo", {}).get("parameters", {})
            
            name = session_params.get("full_name", "Prospect")
            email = session_params.get("email_address", "Not Collected")
            user_context = req.get("text", "User explicitly asked for an agent.")
            
            if send_handoff_notification(name, email, user_context):
                response_text = f"Thank you, {name}. I have securely notified our advisory team. They will review your request and reach out to you at {email} shortly."
            else:
                response_text = "I'm sorry, I couldn't connect you right now. Please try emailing us directly."

        elif intent_name == "Default Welcome Intent":
            response_text = "Welcome to Iapetus AI. How can I assist you today?"
            
        else:
            # --- PHASE 3: FALLBACK LOGIC (Client CMS) ---
            print(f"Unknown intent: '{intent_name}'. Attempting fallback...")
            response_text = handle_knowledge_fallback(user_query)
            
            if response_text is None:
                # Final fallback: Offer a human handoff
                response_text = "I'm sorry, I don't have an answer for that. Would you like to speak to a human advisor?"

        # --- PHASE 4: BUILD AND SEND RESPONSE ---
        res = {
            "fulfillment_response": {
                "messages": [
                    {
                        "text": {
                            "text": [response_text],
                            "allow_playback_interruption": False,
                        }
                    }
                ]
            }
        }
        
        # Return the JSON response with the correct header
        return json.dumps(res), 200, {'Content-Type': 'application/json'}

    except Exception as e:
        print(f"Error in webhook: {e}")
        # Send a safe error response back to the user
        res = {
            "fulfillment_response": {
                "messages": [
                    {
                        "text": {
                            "text": ["I'm sorry, I seem to be having a technical issue. Please try again in a moment."],
                            "allow_playback_interruption": False,
                        }
                    }
                ]
            }
        }
        # Return the JSON error response with the correct header
        return json.dumps(res), 200, {'Content-Type': 'application/json'}