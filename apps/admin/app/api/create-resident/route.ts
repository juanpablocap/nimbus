import { createClient } from "@supabase/supabase-js";
import { NextRequest, NextResponse } from "next/server";

const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { email, password, full_name, phone, community_id, property_id } = body;

    // 1. Create auth user
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError) return NextResponse.json({ error: authError.message }, { status: 400 });

    const userId = authData.user.id;

    // 2. Create profile
    const { error: profileError } = await supabaseAdmin.from("profiles").insert({
      id: userId,
      community_id,
      full_name,
      phone,
    });

    if (profileError) return NextResponse.json({ error: profileError.message }, { status: 400 });

    // 3. Assign resident role
    const { data: role } = await supabaseAdmin
      .from("roles")
      .select("id")
      .eq("community_id", community_id)
      .eq("name", "resident")
      .single();

    if (role) {
      await supabaseAdmin.from("user_roles").insert({
        user_id: userId,
        role_id: role.id,
        community_id,
      });
    }

    // 4. Assign property if selected
    if (property_id) {
      await supabaseAdmin.from("resident_properties").insert({
        profile_id: userId,
        property_id,
        community_id,
      });
    }

    return NextResponse.json({ success: true, userId });
  } catch (err: unknown) {
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
