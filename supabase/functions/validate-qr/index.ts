import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
import { verifyQRToken } from "../_shared/qr-jwt.ts";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // Verify user is authenticated (guard)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    // Parse request body
    const { qr_token, action = "entry" } = await req.json();
    if (!qr_token) return errorResponse("qr_token is required");

    // Step 1: Verify JWT signature and expiration
    let payload;
    try {
      payload = await verifyQRToken(qr_token);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Invalid token";
      if (message.includes("exp")) {
        return jsonResponse({
          valid: false,
          reason: "expired",
          message: "This QR code has expired",
        });
      }
      return jsonResponse({
        valid: false,
        reason: "invalid",
        message: "Invalid QR code",
      });
    }

    const supabaseAdmin = getSupabaseAdmin();

    // Step 2: Get visit from database
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*, properties(name, address), profiles!visits_created_by_fkey(full_name, phone)")
      .eq("id", payload.visit_id)
      .single();

    if (visitError || !visit) {
      return jsonResponse({
        valid: false,
        reason: "not_found",
        message: "Visit not found in the system",
      });
    }

    // Step 3: Verify visit is active
    if (visit.status !== "active") {
      return jsonResponse({
        valid: false,
        reason: "inactive",
        message: `Visit is ${visit.status}`,
      });
    }

    // Step 4: Check usage limit
    if (visit.times_used >= visit.max_uses) {
      return jsonResponse({
        valid: false,
        reason: "max_uses_reached",
        message: "This QR code has reached its maximum number of uses",
      });
    }

    // Step 5: Check time validity
    if (visit.valid_until && new Date(visit.valid_until) < new Date()) {
      // Update status to expired
      await supabaseAdmin
        .from("visits")
        .update({ status: "expired", updated_at: new Date().toISOString() })
        .eq("id", visit.id);

      return jsonResponse({
        valid: false,
        reason: "expired",
        message: "This visit has expired",
      });
    }

    // Step 6: Verify guard belongs to the same community
    const { data: guardProfile } = await supabaseAdmin
      .from("profiles")
      .select("community_id")
      .eq("id", user.id)
      .single();

    if (!guardProfile || guardProfile.community_id !== visit.community_id) {
      return jsonResponse({
        valid: false,
        reason: "wrong_community",
        message: "This visit belongs to a different community",
      });
    }

    // QR is valid — return visit details for guard confirmation
    return jsonResponse({
      valid: true,
      visit: {
        id: visit.id,
        visitor_name: visit.visitor_name,
        visitor_document: visit.visitor_document,
        visit_type: visit.visit_type,
        notes: visit.notes,
        times_used: visit.times_used,
        max_uses: visit.max_uses,
        valid_until: visit.valid_until,
        property: {
          name: visit.properties?.name,
          address: visit.properties?.address,
        },
        resident: {
          name: visit.profiles?.full_name,
          phone: visit.profiles?.phone,
        },
      },
    });
  } catch (err) {
    console.error("validate-qr error:", err);
    return errorResponse("Internal server error", 500);
  }
});

