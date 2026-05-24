"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface AccessLog {
  id: string;
  visitor_name: string;
  action: string;
  method: string;
  notes: string | null;
  created_at: string;
  properties: { name: string } | null;
  visit_id: string | null;
  validated_by_profile: { full_name: string } | null;
}

export default function AccessLogsPage() {
  const [logs, setLogs] = useState<AccessLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [dateFilter, setDateFilter] = useState("");

  async function fetchLogs() {
    setLoading(true);
    let query = supabase
      .from("access_logs")
      .select("id, visitor_name, action, method, notes, created_at, visit_id, properties(name), validated_by_profile:profiles!access_logs_validated_by_fkey(full_name)")
      .order("created_at", { ascending: false })
      .limit(100);

    if (dateFilter) {
      const start = new Date(dateFilter);
      const end = new Date(dateFilter);
      end.setDate(end.getDate() + 1);
      query = query.gte("created_at", start.toISOString()).lt("created_at", end.toISOString());
    }

    const { data } = await query;
    setLogs((data as any) ?? []);
    setLoading(false);
  }

  useEffect(() => { fetchLogs(); }, [dateFilter]);

  function formatTime(d: string) {
    return new Date(d).toLocaleString("en-US", {
      month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
    });
  }

  const methodLabels: Record<string, string> = { qr: "QR Code", manual: "Manual", plate: "Plate" };
  const actionLabels: Record<string, string> = { entry: "Entry", exit: "Exit" };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Access Logs</h1>
          <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{logs.length} entries</p>
        </div>
      </div>

      <div style={{ marginBottom: 16 }}>
        <input type="date" value={dateFilter} onChange={(e) => setDateFilter(e.target.value)}
          style={{
            padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }} />
        {dateFilter && (
          <button onClick={() => setDateFilter("")} style={{
            marginLeft: 8, padding: "9px 12px", fontSize: 14,
            background: "none", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-secondary)", cursor: "pointer",
          }}>Clear</button>
        )}
      </div>

      {loading ? (
        <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>
      ) : logs.length === 0 ? (
        <div className="nimbus-card" style={{ padding: 32, textAlign: "center" }}>
          <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>No access logs found.</p>
        </div>
      ) : (
        <div className="nimbus-card" style={{ overflow: "hidden" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border)" }}>
                <th style={thStyle}>Visitor</th>
                <th style={thStyle}>Property</th>
                <th style={thStyle}>Action</th>
                <th style={thStyle}>Method</th>
                <th style={thStyle}>Validated by</th>
                <th style={thStyle}>Time</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log) => (
                <tr key={log.id} style={{ borderBottom: "1px solid var(--border)" }}>
                  <td style={tdStyle}>
                    <span style={{ fontWeight: 500, color: "var(--text-primary)" }}>{log.visitor_name}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{log.properties?.name ?? "—"}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      display: "inline-block", padding: "2px 8px", fontSize: 12, fontWeight: 500,
                      borderRadius: 9999,
                      background: log.action === "entry" ? "#dcfce7" : "#dbeafe",
                      color: log.action === "entry" ? "#16a34a" : "#2563eb",
                    }}>{actionLabels[log.action] ?? log.action}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{methodLabels[log.method] ?? log.method}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{log.validated_by_profile?.full_name ?? "—"}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-tertiary)", whiteSpace: "nowrap" }}>{formatTime(log.created_at)}</span>
                  </td>
                </tr>
              ))}
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
