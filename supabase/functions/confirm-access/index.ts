import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";

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
    const { visit_id, action = "entry", notes = null } = await req.json();
    if (!visit_id) return errorResponse("visit_id is required");

    const supabaseAdmin = getSupabaseAdmin();

    // Get visit
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*")
      .eq("id", visit_id)
      .single();

    if (visitError || !visit) return errorResponse("Visit not found", 404);

    // Verify visit is still active and within limits
    if (visit.status !== "active") return errorResponse("Visit is not active", 400);
    if (visit.times_used >= visit.max_uses) return errorResponse("Visit has reached max uses", 400);

    // Register access log
    const { error: logError } = await supabaseAdmin
      .from("access_logs")
      .insert({
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

    // Update visit usage count
    const newTimesUsed = visit.times_used + 1;
    const newStatus = newTimesUsed >= visit.max_uses ? "used" : "active";

    await supabaseAdmin
      .from("visits")
      .update({
        times_used: newTimesUsed,
        status: newStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", visit.id);

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

