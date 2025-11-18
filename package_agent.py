import cloudpickle
import os
import sys

# 1. Setup Path
sys.path.append(os.getcwd())

try:
    # 2. Import the Modules
    # Import your local app code
    import adk 
    from adk.agent import root_agent
    
    # CRITICAL: Import the Google ADK library from your system
    import google.adk 

    # 3. THE FIX: Bundle EVERYTHING by Value
    # This forces the serializer to copy the code for both your app AND the library
    # into the file, so the cloud doesn't need to install anything.
    cloudpickle.register_pickle_by_value(adk)
    cloudpickle.register_pickle_by_value(google.adk)

    # 4. Serialize
    output_file = 'agent_code.pkl'
    print(f"Serializing agent to {output_file} with bundled app AND library code...")
    
    with open(output_file, 'wb') as f:
        cloudpickle.dump(root_agent, f)

    print("Agent serialization complete. Ready for upload.")

except ImportError as e:
    print(f"Import Error: {e}")
    print("Make sure you are in the project root and 'google-adk' is installed.")
except Exception as e:
    print(f"Error: {e}")