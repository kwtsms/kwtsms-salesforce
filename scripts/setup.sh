#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup.sh - kwtSMS Salesforce dev environment setup
# -----------------------------------------------------------------------------
# Prerequisites:
#   - Salesforce CLI (sf) installed: https://developer.salesforce.com/tools/salesforcecli
#   - A Dev Hub org already enabled
# -----------------------------------------------------------------------------

set -euo pipefail

echo "==> Checking for Salesforce CLI..."
if ! command -v sf &>/dev/null; then
  echo "ERROR: 'sf' CLI not found. Install it from https://developer.salesforce.com/tools/salesforcecli"
  exit 1
fi
sf --version

# Step 1: Authenticate to Dev Hub
echo ""
echo "==> Authenticating to Dev Hub..."
echo "    A browser window will open. Log in with your Dev Hub credentials."
sf org login web --set-default-dev-hub --alias kwtsms-hub

# Step 2: Create a scratch org
echo ""
echo "==> Creating scratch org (expires in 30 days)..."
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias kwtsms-scratch \
  --duration-days 30 \
  --set-default

# Step 3: Push source to scratch org
echo ""
echo "==> Pushing source to scratch org..."
sf project deploy start

# Step 4: Assign permission set
echo ""
echo "==> Assigning KwtSMS_Admin permission set..."
sf org assign permset --name KwtSMS_Admin || echo "  (Permission set not found yet - assign manually after creation)"

# Step 5: Open the scratch org
echo ""
echo "==> Opening scratch org in browser..."
sf org open

echo ""
echo "Setup complete. Your scratch org is ready."
echo "Open the App Launcher and search for 'kwtSMS' to get started."
