#!/bin/bash
# ═══════════════════════════════════════════════════════
# deploy.sh — Sube los archivos a GitHub y activa Pages
# Uso: bash deploy.sh
# ═══════════════════════════════════════════════════════

TOKEN="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"
REPO="nicolucci92/Inversiones"
BRANCH="main"
API="https://api.github.com"

upload_file() {
  local FILE="$1"
  local PATH_IN_REPO="$2"
  local CONTENT
  CONTENT=$(base64 < "$FILE" | tr -d '\n')

  # Check if file exists (to get SHA for update)
  local SHA
  SHA=$(curl -s -H "Authorization: token $TOKEN" \
    "$API/repos/$REPO/contents/$PATH_IN_REPO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null)

  local BODY
  if [ -n "$SHA" ]; then
    BODY=$(python3 -c "import json; print(json.dumps({'message':'Deploy: update $PATH_IN_REPO','content':'$CONTENT','sha':'$SHA','branch':'$BRANCH'}))")
  else
    BODY=$(python3 -c "import json; print(json.dumps({'message':'Deploy: add $PATH_IN_REPO','content':'$CONTENT','branch':'$BRANCH'}))")
  fi

  local STATUS
  STATUS=$(curl -s -o /tmp/gh_resp.json -w "%{http_code}" \
    -X PUT \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$API/repos/$REPO/contents/$PATH_IN_REPO")

  if [[ "$STATUS" == "200" || "$STATUS" == "201" ]]; then
    echo "  ✓ $PATH_IN_REPO ($STATUS)"
  else
    echo "  ✗ $PATH_IN_REPO ($STATUS)"
    cat /tmp/gh_resp.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('  →', d.get('message',''))" 2>/dev/null
  fi
}

echo ""
echo "▸ Subiendo archivos al repo $REPO..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

upload_file "$SCRIPT_DIR/index.html"   "index.html"
upload_file "$SCRIPT_DIR/manifest.json" "manifest.json"
upload_file "$SCRIPT_DIR/sw.js"        "sw.js"
upload_file "$SCRIPT_DIR/icon.svg"     "icon.svg"

echo ""
echo "▸ Activando GitHub Pages..."
echo ""

# Try to enable Pages (may already exist)
PAGES_STATUS=$(curl -s -o /tmp/pages_resp.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  -d "{\"source\":{\"branch\":\"$BRANCH\",\"path\":\"/\"}}" \
  "$API/repos/$REPO/pages")

if [[ "$PAGES_STATUS" == "201" ]]; then
  echo "  ✓ GitHub Pages activado"
elif [[ "$PAGES_STATUS" == "409" ]]; then
  echo "  ✓ GitHub Pages ya estaba activo"
  # Update Pages config
  curl -s -o /dev/null -X PUT \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "{\"source\":{\"branch\":\"$BRANCH\",\"path\":\"/\"}}" \
    "$API/repos/$REPO/pages"
else
  echo "  ✗ Pages status: $PAGES_STATUS"
  cat /tmp/pages_resp.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('  →', d.get('message',''))" 2>/dev/null
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Deploy completo"
echo "  URL: https://nicolucci92.github.io/Inversiones"
echo "  (GitHub Pages tarda ~2 min en publicar)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
