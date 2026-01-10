"""
Test script for workspace_manager functionality
"""

from extensions.workspace_manager import get_workspace_manager, scm_workspace_create, scm_workspace_switch, scm_workspace_list, scm_workspace_info

fn main() raises:
    print("Testing Workspace Manager Functionality")
    print("=" * 50)

    # Test workspace creation
    print("1. Creating workspace 'dev'...")
    scm_workspace_create("dev", "Development workspace")

    print("2. Creating workspace 'staging'...")
    scm_workspace_create("staging", "Staging workspace")  # Use default "main" base

    print("3. Listing all workspaces...")
    scm_workspace_list()

    print("4. Getting workspace info for 'dev'...")
    scm_workspace_info("dev")

    print("5. Switching to workspace 'dev'...")
    scm_workspace_switch("dev")

    print("6. Creating workspace 'feature-x' from 'dev'...")
    scm_workspace_create("feature-x", "Feature X development", "dev")

    print("7. Listing all workspaces after creation...")
    scm_workspace_list()

    print("8. Switching to workspace 'feature-x'...")
    scm_workspace_switch("feature-x")

    print("Workspace functionality test completed successfully!")