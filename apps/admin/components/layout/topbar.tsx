"use client";

import { useTheme } from "@/components/theme-provider";
import { useAuth } from "@/components/auth-provider";
import { signOut } from "@/lib/auth";
import { useRouter } from "next/navigation";
import { Icon } from "@/components/ui/icon";

export function Topbar() {
  const { theme, toggleTheme } = useTheme();
  const { user } = useAuth();
  const router = useRouter();

  async function handleLogout() {
    await signOut();
    router.push("/login");
  }

  const initial = user?.email?.charAt(0).toUpperCase() ?? "?";

  return (
    <header style={{ height: "var(--topbar-height)", display: "flex", alignItems: "center", gap: 16, padding: "0 24px", background: "var(--bg-card)", borderBottom: "1px solid var(--border)", position: "sticky", top: 0, zIndex: 30 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, flex: 1, maxWidth: 400, background: "var(--bg-secondary)", border: "1px solid var(--border)", borderRadius: "var(--radius-md)", padding: "0 12px" }}>
        <Icon name="search" size={16} />
        <input type="text" placeholder="Search..." style={{ border: "none", background: "none", outline: "none", color: "var(--text-primary)", fontSize: 14, padding: "8px 0", width: "100%" }} />
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 4, marginLeft: "auto" }}>
        <button onClick={toggleTheme} aria-label="Toggle theme" style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", border: "none", background: "none", color: "var(--text-secondary)", cursor: "pointer", borderRadius: "var(--radius-md)" }}>
          <Icon name={theme === "light" ? "moon" : "sun"} size={18} />
        </button>
        <button aria-label="Notifications" style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", border: "none", background: "none", color: "var(--text-secondary)", cursor: "pointer", borderRadius: "var(--radius-md)" }}>
          <Icon name="bell" size={18} />
        </button>
        <button onClick={handleLogout} aria-label="Sign out" title="Sign out" style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", border: "none", background: "none", color: "var(--text-secondary)", cursor: "pointer", borderRadius: "var(--radius-md)" }}>
          <Icon name="log-out" size={18} />
        </button>
        <div style={{ width: 34, height: 34, background: "var(--accent)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", marginLeft: 4 }}>
          <span style={{ color: "white", fontSize: 14, fontWeight: 600 }}>{initial}</span>
        </div>
      </div>
    </header>
  );
}
