"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface Visit {
  id: string;
  visitor_name: string;
  visitor_document: string | null;
  visit_type: string;
  status: string;
  valid_from: string;
  valid_until: string | null;
  max_uses: number;
  times_used: number;
  notes: string | null;
  created_at: string;
  properties: { name: string } | null;
  created_by_profile: { full_name: string } | null;
}

export default function VisitsPage() {
  const [visits, setVisits] = useState<Visit[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  async function fetchVisits() {
    setLoading(true);
    let query = supabase
      .from("visits")
      .select("*, properties(name), created_by_profile:profiles!visits_created_by_fkey(full_name)")
      .order("created_at", { ascending: false });

    if (statusFilter !== "all") {
      query = query.eq("status", statusFilter);
    }

    const { data } = await query;
    setVisits((data as any) ?? []);
    setLoading(false);
  }

  useEffect(() => { fetchVisits(); }, [statusFilter]);

  const filtered = visits.filter((v) =>
    v.visitor_name.toLowerCase().includes(search.toLowerCase())
  );

  function formatDate(d: string) {
    return new Date(d).toLocaleString("en-US", {
      month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
    });
  }

  const statusColors: Record<string, { bg: string; color: string }> = {
    active: { bg: "#dcfce7", color: "#16a34a" },
    used: { bg: "#dbeafe", color: "#2563eb" },
    expired: { bg: "#fee2e2", color: "#dc2626" },
    cancelled: { bg: "#f4f4f5", color: "#71717a" },
  };

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Visits</h1>
        <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{visits.length} total</p>
      </div>

      <div style={{ display: "flex", gap: 12, marginBottom: 16, flexWrap: "wrap" }}>
        <input type="text" placeholder="Search visitor..." value={search} onChange={(e) => setSearch(e.target.value)}
          style={{
            flex: 1, minWidth: 200, maxWidth: 360, padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }} />
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
          style={{
            padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }}>
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="used">Used</option>
          <option value="expired">Expired</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>

      {loading ? (
        <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>
      ) : filtered.length === 0 ? (
        <div className="nimbus-card" style={{ padding: 32, textAlign: "center" }}>
          <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>
            {search || statusFilter !== "all" ? "No visits match your filters." : "No visits yet. Residents create visits from the mobile app."}
          </p>
        </div>
      ) : (
        <div className="nimbus-card" style={{ overflow: "hidden" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border)" }}>
                <th style={thStyle}>Visitor</th>
                <th style={thStyle}>Property</th>
                <th style={thStyle}>Created by</th>
                <th style={thStyle}>Type</th>
                <th style={thStyle}>Status</th>
                <th style={thStyle}>Valid until</th>
                <th style={thStyle}>Uses</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((v) => {
                const sc = statusColors[v.status] ?? { bg: "#f4f4f5", color: "#71717a" };
                return (
                  <tr key={v.id} style={{ borderBottom: "1px solid var(--border)" }}>
                    <td style={tdStyle}>
                      <span style={{ fontWeight: 500, color: "var(--text-primary)" }}>{v.visitor_name}</span>
                      {v.visitor_document && <p style={{ fontSize: 12, color: "var(--text-tertiary)" }}>{v.visitor_document}</p>}
                    </td>
                    <td style={tdStyle}><span style={{ color: "var(--text-secondary)" }}>{v.properties?.name ?? "—"}</span></td>
                    <td style={tdStyle}><span style={{ color: "var(--text-secondary)" }}>{v.created_by_profile?.full_name ?? "—"}</span></td>
                    <td style={tdStyle}><span style={{ color: "var(--text-secondary)", textTransform: "capitalize" }}>{v.visit_type.replace("_", " ")}</span></td>
                    <td style={tdStyle}>
                      <span style={{
                        display: "inline-block", padding: "2px 8px", fontSize: 12, fontWeight: 500,
                        borderRadius: 9999, background: sc.bg, color: sc.color, textTransform: "capitalize",
                      }}>{v.status}</span>
                    </td>
                    <td style={tdStyle}><span style={{ color: "var(--text-tertiary)", whiteSpace: "nowrap" }}>{v.valid_until ? formatDate(v.valid_until) : "—"}</span></td>
                    <td style={tdStyle}><span style={{ color: "var(--text-secondary)" }}>{v.times_used}/{v.max_uses}</span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

const thStyle: React.CSSProperties = {
  textAlign: "left", padding: "10px 16px", fontSize: 12, fontWeight: 600,
  textTransform: "uppercase", letterSpacing: "0.05em", color: "var(--text-tertiary)",
};
const tdStyle: React.CSSProperties = { padding: "12px 16px" };
