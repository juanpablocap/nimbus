import { create, verify, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const QR_SECRET = Deno.env.get("QR_JWT_SECRET") || "nimbus-qr-secret-change-me";

// Import key for HMAC signing
async function getKey(): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(QR_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export interface QRPayload {
  visit_id: string;
  community_id: string;
  property_id: string;
  visitor_name: string;
  max_uses: number;
  exp: number;
}

export async function generateQRToken(payload: Omit<QRPayload, "exp">, expiresAt: Date): Promise<string> {
  const key = await getKey();
  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      visit_id: payload.visit_id,
      community_id: payload.community_id,
      property_id: payload.property_id,
      visitor_name: payload.visitor_name,
      max_uses: payload.max_uses,
      exp: getNumericDate(expiresAt),
    },
    key,
  );
  return jwt;
}

export async function verifyQRToken(token: string): Promise<QRPayload> {
  const key = await getKey();
  const payload = await verify(token, key);
  return payload as unknown as QRPayload;
}

