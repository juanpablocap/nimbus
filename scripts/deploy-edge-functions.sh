#!/bin/bash
# ============================================
# Nimbus — Deploy Edge Functions to Supabase
# ============================================
# Run from the nimbus root directory:
#   chmod +x scripts/deploy-edge-functions.sh
#   ./scripts/deploy-edge-functions.sh
# ============================================

set -e

PROJECT_REF="yxdwshujxsnamnmllljc"

echo "🔗 Linking Supabase project..."
npx supabase link --project-ref $PROJECT_REF

echo ""
echo "🚀 Deploying generate-qr..."
npx supabase functions deploy generate-qr --no-verify-jwt

echo ""
echo "🚀 Deploying validate-qr..."
npx supabase functions deploy validate-qr --no-verify-jwt

echo ""
echo "🚀 Deploying confirm-access..."
npx supabase functions deploy confirm-access --no-verify-jwt

echo ""
echo "🔐 Setting QR_JWT_SECRET..."
echo "Enter a secret key for signing QR tokens (or press Enter for default):"
read -r SECRET
if [ -z "$SECRET" ]; then
  SECRET="nimbus-qr-$(openssl rand -hex 16)"
  echo "Generated secret: $SECRET"
fi
npx supabase secrets set QR_JWT_SECRET="$SECRET"

echo ""
echo "✅ All Edge Functions deployed!"
echo ""
echo "Endpoints:"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/generate-qr"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/validate-qr"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/confirm-access"
echo ""
echo "Test with:"
echo "  curl -X POST https://$PROJECT_REF.supabase.co/functions/v1/validate-qr \\"
echo "    -H 'Authorization: Bearer YOUR_JWT' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"qr_token\": \"test\"}'"

