import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
import { verifyQRToken } from "../_shared/qr-jwt.ts";
import { requireRole } from "../_shared/auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsResponse();

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    const supabaseAdmin = getSupabaseAdmin();

    // Caller must be a guard or higher
    const auth = await requireRole(supabaseAdmin, user.id, "guard");
    if (!auth) return errorResponse("Only guards can confirm access", 403);

    // Require qr_token — re-verify cryptographically, derive visit_id from token
    const { qr_token, action = "entry", notes = null } = await req.json();
    if (!qr_token) return errorResponse("qr_token is required");

    let payload;
    try {
      payload = await verifyQRToken(qr_token);
    } catch {
      return errorResponse("Invalid or expired QR token", 400);
    }

    if (payload.community_id !== auth.communityId) {
      return errorResponse("This visit belongs to a different community", 403);
    }

    const visitId = payload.visit_id;

    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*")
      .eq("id", visitId)
      .single();

    if (visitError || !visit) return errorResponse("Visit not found", 404);
    if (visit.community_id !== auth.communityId) return errorResponse("Community mismatch", 403);
    if (visit.status !== "active") return errorResponse("Visit is not active", 400);
    if (visit.times_used >= visit.max_uses) return errorResponse("Visit has reached max uses", 400);
    if (visit.valid_until && new Date(visit.valid_until) < new Date()) {
      await supabaseAdmin.from("visits").update({ status: "expired", updated_at: new Date().toISOString() }).eq("id", visit.id);
      return errorResponse("Visit has expired", 400);
    }

    const { error: logError } = await supabaseAdmin.from("access_logs").insert({
      community_id: visit.community_id,
      visit_id: visit.id,
      property_id: visit.property_id,
      visitor_name: visit.visitor_name,
      validated_by: user.id,
      action,
      method: "qr",
      notes,
    });

    if (logError) return errorResponse("Failed to register access log", 500);

    const newTimesUsed = visit.times_used + 1;
    const newStatus = newTimesUsed >= visit.max_uses ? "used" : "active";

    await supabaseAdmin.from("visits").update({
      times_used: newTimesUsed,
      status: newStatus,
      updated_at: new Date().toISOString(),
    }).eq("id", visit.id);

    return jsonResponse({
      success: true,
      access_log: {
        action,
        visitor_name: visit.visitor_name,
        times_used: newTimesUsed,
        max_uses: visit.max_uses,
        visit_status: newStatus,
      },
    });
  } catch (err) {
    console.error("confirm-access error:", err);
    return errorResponse("Internal server error", 500);
  }
});
