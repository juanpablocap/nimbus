import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

export interface AuthContext {
  userId: string;
  communityId: string;
  role: string;
}

const ROLE_HIERARCHY: Record<string, number> = {
  resident: 1,
  guard: 2,
  admin: 3,
  superadmin: 4,
};

export async function requireRole(
  supabase: SupabaseClient,
  userId: string,
  minRole: string
): Promise<AuthContext | null> {
  const { data: profile, error } = await supabase
    .from("profiles")
    .select("community_id, role")
    .eq("id", userId)
    .single();

  if (error || !profile) return null;

  const userLevel = ROLE_HIERARCHY[profile.role] ?? 0;
  const requiredLevel = ROLE_HIERARCHY[minRole] ?? 99;

  if (userLevel < requiredLevel) return null;

  return {
    userId,
    communityId: profile.community_id,
    role: profile.role,
  };
}
