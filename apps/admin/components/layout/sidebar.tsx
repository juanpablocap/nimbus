"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { navigation } from "@/lib/navigation";
import { Icon } from "@/components/ui/icon";

export function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const w = collapsed ? "var(--sidebar-width-collapsed)" : "var(--sidebar-width)";

  return (
    <aside style={{ position: "fixed", top: 0, left: 0, height: "100vh", width: w, background: "var(--bg-sidebar)", display: "flex", flexDirection: "column", transition: "width var(--transition-slow)", zIndex: 40, overflow: "hidden", borderRight: "1px solid rgba(255,255,255,0.06)" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: collapsed ? "center" : "space-between", padding: collapsed ? "20px 12px" : "20px 16px", minHeight: "var(--topbar-height)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, overflow: "hidden" }}>
          <div style={{ width: 36, height: 36, background: "var(--accent)", borderRadius: "var(--radius-md)", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: 700, fontSize: 18, flexShrink: 0 }}>N</div>
          {!collapsed && <span style={{ fontSize: 20, fontWeight: 700, color: "var(--text-sidebar-active)", whiteSpace: "nowrap", letterSpacing: "-0.5px" }}>Nimbus</span>}
        </div>
        {!collapsed && (
          <button onClick={() => setCollapsed(true)} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", border: "none", background: "rgba(255,255,255,0.06)", color: "var(--text-sidebar-muted)", borderRadius: "var(--radius-sm)", cursor: "pointer", flexShrink: 0 }}>
            <Icon name="chevron-left" size={16} />
          </button>
        )}
        {collapsed && (
          <button onClick={() => setCollapsed(false)} style={{ position: "absolute", top: 20, right: -14, width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", border: "1px solid var(--border)", background: "var(--bg-card)", color: "var(--text-secondary)", borderRadius: "50%", cursor: "pointer", zIndex: 50, boxShadow: "var(--shadow-sm)" }}>
            <Icon name="chevron-right" size={14} />
          </button>
        )}
      </div>

      <nav style={{ flex: 1, padding: collapsed ? "8px" : "8px 12px", overflowY: "auto", display: "flex", flexDirection: "column", gap: 24 }}>
        {navigation.map((section) => (
          <div key={section.title}>
            {!collapsed && <span style={{ display: "block", fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.08em", color: "var(--text-sidebar-muted)", padding: "0 8px", marginBottom: 4 }}>{section.title}</span>}
            <ul style={{ listStyle: "none", margin: 0, padding: 0, display: "flex", flexDirection: "column", gap: 2 }}>
              {section.items.map((item) => {
                const active = pathname === item.href;
                return (
                  <li key={item.href}>
                    <Link href={item.href} title={collapsed ? item.label : undefined} style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? 10 : "9px 10px", justifyContent: collapsed ? "center" : "flex-start", borderRadius: "var(--radius-md)", color: active ? "var(--text-sidebar-active)" : "var(--text-sidebar)", background: active ? "rgba(255,255,255,0.1)" : "transparent", textDecoration: "none", fontSize: 14, fontWeight: 450, whiteSpace: "nowrap", overflow: "hidden", transition: "all var(--transition-fast)" }}>
                      <Icon name={item.icon} size={20} />
                      {!collapsed && <span>{item.label}</span>}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      <div style={{ padding: 12, borderTop: "1px solid rgba(255,255,255,0.06)" }}>
        <Link href="/settings" title={collapsed ? "Settings" : undefined} style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? 10 : "9px 10px", justifyContent: collapsed ? "center" : "flex-start", borderRadius: "var(--radius-md)", color: "var(--text-sidebar)", textDecoration: "none", fontSize: 14, fontWeight: 450 }}>
          <Icon name="settings" size={20} />
          {!collapsed && <span>Settings</span>}
        </Link>
      </div>
    </aside>
  );
}
