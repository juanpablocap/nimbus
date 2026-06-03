import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
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

    const auth = await requireRole(supabaseAdmin, user.id, "guard");
    if (!auth) return errorResponse("Only guards can register manual access", 403);

    const { visitor_name, visitor_document, property_id, action = "entry", notes = null } = await req.json();
    if (!visitor_name) return errorResponse("visitor_name is required");
    if (!property_id) return errorResponse("property_id is required");

    // Verify property belongs to guard community
    const { data: property, error: propError } = await supabaseAdmin
      .from("properties")
      .select("id, community_id")
      .eq("id", property_id)
      .single();

    if (propError || !property) return errorResponse("Property not found", 404);
    if (property.community_id !== auth.communityId) return errorResponse("Property belongs to a different community", 403);

    const { data: log, error: logError } = await supabaseAdmin
      .from("access_logs")
      .insert({
        community_id: auth.communityId,
        visit_id: null,
        property_id,
        visitor_name,
        visitor_document: visitor_document ?? null,
        validated_by: user.id,
        action,
        method: "manual",
        notes,
      })
      .select()
      .single();

    if (logError) return errorResponse("Failed to register access log", 500);

    return jsonResponse({ success: true, access_log: log });
  } catch (err) {
    console.error("manual-access error:", err);
    return errorResponse("Internal server error", 500);
  }
});
