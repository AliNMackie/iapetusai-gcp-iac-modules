# agent_definition.py
# This file defines the conversational logic, tool integrations, etc.

from adk.agent import ConversationalAgent
from adk.tools import CloudFunctionTool

# 1. Define the Cloud Function Tool for Lead Capture
# The URL must be the fully qualified URL of your deployed Cloud Function.
lead_capture_tool = CloudFunctionTool(
    name="LeadCaptureHandler",
    description="Handles sales inquiries and qualified lead capture.",
    url="YOUR_CF_LEAD_CAPTURE_HANDLER_URL" 
)

# 2. Define the Agent
def create_agent():
    """Creates the main conversational agent instance."""
    agent = ConversationalAgent(
        name="IndustrializedBot",
        description="Enterprise conversational AI for sales and support.",
        tools=[lead_capture_tool],
        # Add other configurations like safety, routing, etc.
    )
    return agent

# CRITICAL: The serialization script below imports and uses this function!