import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
import { generateQRToken } from "../_shared/qr-jwt.ts";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // Verify user is authenticated
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    // Parse request body
    const { visit_id } = await req.json();
    if (!visit_id) return errorResponse("visit_id is required");

    const supabaseAdmin = getSupabaseAdmin();

    // Get the visit and verify ownership
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*, properties(name)")
      .eq("id", visit_id)
      .single();

    if (visitError || !visit) return errorResponse("Visit not found", 404);

    // Verify the user owns this visit
    if (visit.created_by !== user.id) {
      return errorResponse("You can only generate QR for your own visits", 403);
    }

    // Verify visit is active
    if (visit.status !== "active") {
      return errorResponse("Visit is not active", 400);
    }

    // Generate expiration: use valid_until or default to 24 hours
    const expiresAt = visit.valid_until
      ? new Date(visit.valid_until)
      : new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Check if already expired
    if (expiresAt < new Date()) {
      return errorResponse("Visit has already expired", 400);
    }

    // Generate QR token
    const qrToken = await generateQRToken(
      {
        visit_id: visit.id,
        community_id: visit.community_id,
        property_id: visit.property_id,
        visitor_name: visit.visitor_name,
        max_uses: visit.max_uses,
      },
      expiresAt,
    );

    // Save token to visit
    await supabaseAdmin
      .from("visits")
      .update({ qr_token: qrToken, updated_at: new Date().toISOString() })
      .eq("id", visit_id);

    return jsonResponse({
      qr_token: qrToken,
      visit_id: visit.id,
      visitor_name: visit.visitor_name,
      property_name: visit.properties?.name,
      expires_at: expiresAt.toISOString(),
      max_uses: visit.max_uses,
      times_used: visit.times_used,
    });
  } catch (err) {
    console.error("generate-qr error:", err);
    return errorResponse("Internal server error", 500);
  }
});

