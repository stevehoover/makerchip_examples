#!/bin/bash
#
# Create a Makerchip project using the REST API with curl
# Based on reverse-engineering the makerchip-app package
#

set -e

SERVER="https://makerchip.com"
COOKIE_JAR=$(mktemp)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup on exit
trap "rm -f $COOKIE_JAR" EXIT

echo "Makerchip REST API Demo (curl version)"
echo "======================================================"

# Step 1: Authenticate
echo -n "Authenticating... "
if curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" "${SERVER}/auth/pub/" > /dev/null; then
    echo -e "${GREEN}✓ Authenticated${NC}"
else
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
fi

# Step 2: Create project
echo -n "Creating project... "

# Example TL-Verilog code (URL-encoded for POST data)
DESIGN_NAME="counter_example.tlv"
DESIGN_SOURCE=$(cat <<'EOF'
\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m5_makerchip_module
\TLV

   // Simple counter example
   $reset = *reset;

   $cnt[7:0] = $reset ? 0 : >>1$cnt + 1;

   *passed = $cnt == 8'd100;
   *failed = 1'b0;

\SV
   endmodule
EOF
)

# URL encode the data
ENCODED_SOURCE=$(printf "%s" "$DESIGN_SOURCE" | jq -sRr @uri)
ENCODED_NAME=$(printf "%s" "$DESIGN_NAME" | jq -sRr @uri)

# Create the project
RESPONSE=$(curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data "name=${ENCODED_NAME}&source=${ENCODED_SOURCE}" \
    "${SERVER}/project/public/")

# Extract project path from JSON response
PROJ_PATH=$(echo "$RESPONSE" | jq -r '.path')

if [ -n "$PROJ_PATH" ] && [ "$PROJ_PATH" != "null" ]; then
    echo -e "${GREEN}✓ Project created: $PROJ_PATH${NC}"
else
    echo -e "${RED}✗ Project creation failed${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

# Step 3: Display project URL
PROJECT_URL="${SERVER}/sandbox/public/${PROJ_PATH}"
echo ""
echo -e "${BLUE}🌐 Open in browser:${NC} $PROJECT_URL"
echo -e "${BLUE}📋 Project ID:${NC} $PROJ_PATH"

# Step 4: Fetch design contents (verification)
echo ""
echo -n "Fetching design contents... "
CONTENTS=$(curl -s -b "$COOKIE_JAR" "${SERVER}/project/public/${PROJ_PATH}/contents")
DESIGN_LENGTH=$(echo "$CONTENTS" | jq -r '.value | length')
echo -e "${GREEN}✓ Retrieved ${DESIGN_LENGTH} characters${NC}"

# Step 5: Optional cleanup
echo ""
read -p "Press Enter to delete the project, or Ctrl+C to keep it... "
curl -s -b "$COOKIE_JAR" "${SERVER}/project/public/${PROJ_PATH}/delete" > /dev/null
echo -e "${GREEN}✓ Project deleted${NC}"
