#!/usr/bin/env bash
set -euo pipefail

# Deploy latest mod build to Steam Workshop
# Usage: ./scripts/deploy-workshop.sh [changenote]

REPO="wisdommen/botato"
APP_ID="1942280"
PUBLISHED_FILE_ID="3707261407"
STEAM_USER="88bao"
STEAMCMD="/tmp/steamcmd/steamcmd.sh"
WORK_DIR="/tmp/workshop_upload"

# Get latest successful run
echo "Fetching latest artifact from GitHub Actions..."
RUN_ID=$(gh run list --repo "$REPO" --workflow=package-mod.yml --status=success --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    echo "ERROR: No successful workflow runs found."
    exit 1
fi

echo "Run ID: $RUN_ID"

# Download artifact
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/content"
gh run download "$RUN_ID" --repo "$REPO" --dir "$WORK_DIR/download"

# Find and copy the zip
ZIP_FILE=$(find "$WORK_DIR/download" -name "*.zip" -type f | head -1)
if [ -z "$ZIP_FILE" ]; then
    echo "ERROR: No zip file found in artifact."
    exit 1
fi

cp "$ZIP_FILE" "$WORK_DIR/content/"
echo "Artifact: $(basename "$ZIP_FILE")"

# Change note
CHANGENOTE="${1:-"Update from $(git -C "$(dirname "$0")/.." rev-parse --short HEAD)"}"

# Write VDF
cat > "$WORK_DIR/workshop_item.vdf" <<EOF
"workshopitem"
{
    "appid"           "$APP_ID"
    "publishedfileid" "$PUBLISHED_FILE_ID"
    "contentfolder"   "$WORK_DIR/content"
    "visibility"      "2"
    "changenote"      "$CHANGENOTE"
}
EOF

echo "Uploading to Steam Workshop (hidden)..."
echo "Change note: $CHANGENOTE"

# Upload
"$STEAMCMD" +login "$STEAM_USER" \
    +workshop_build_item "$WORK_DIR/workshop_item.vdf" \
    +quit

echo "Done. Clean up with: rm -rf $WORK_DIR"
