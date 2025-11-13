# --- File: agent_app/agent.py ---
# This is your complete agent definition file.

# --- 1. CORRECT IMPORTS ---
from google.adk.agents.llm_agent import Agent
from google.adk.tools import BaseTool # <-- This is correct.

# --- 2. Define the "Lead Capture" Tool (as a dictionary) ---
lead_capture_tool_dict = {
    "description": "Use this tool to capture a new sales lead when a user wants to buy an agent, get a demo, or speak to sales.",
    
    "parameters": {
        "full_name": {
            "type": "STRING",
            "description": "The user's full name",
            "required": True
        },
        "email_address": {
            "type": "STRING",
            "description": "The user's email address",
            "required": True
        },
        "area_of_interest": {
            "type": "STRING",
            "description": "The user's area of interest (e.g., custom agent, pricing, demo)",
            "required": False
        }
    },
    
    # 3. CRITICAL: Connect the fulfillment to your Cloud Function
    "fulfillment": {
        "type": "CLOUD_FUNCTION",
        "tool_name": "lead-capture-handler" # This MUST match your 'function_name' in terraform.tfvars
    }
}

# --- 4. Instantiate the 'BaseTool' OBJECT ---
lead_capture_tool = BaseTool(
    name="sales_lead_capture",
    description="Use this tool to capture a new sales lead when a user wants to buy an agent, get a demo, or speak to sales."
)
lead_capture_tool.parameters = lead_capture_tool_dict["parameters"]
lead_capture_tool.fulfillment = lead_capture_tool_dict["fulfillment"]


# --- 5. Define the Root Agent ---
# We are giving the agent an extremely forceful, single-purpose instruction
# to fix the model's 'hallucination' and force it to use the tool.

root_agent = Agent(
    model='gemini-2.5-flash',
    name='root_agent',
    description='A sales agent for capturing leads.',

    # --- NEW, "SYSTEM SHOCK" INSTRUCTION ---
    instruction=(
        'You are a sales agent. Your ONLY job is to capture leads. '
        'You MUST IGNORE all other questions. '
        'If the user asks about "pricing", "buying", "demo", "contacting sales", or "speak to an advisor", '
        'you MUST use the "sales_lead_capture" tool. '
        'This is your ONLY function. Do not chat. Do not answer questions. '
        'Only use the tool.'
    ),

    tools=[lead_capture_tool]
)