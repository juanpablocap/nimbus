"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface Stats {
  residents: number;
  properties: number;
  activeVisits: number;
  todayEntries: number;
}

interface AccessLog {
  id: string;
  visitor_name: string;
  action: string;
  method: string;
  created_at: string;
  properties: { name: string } | null;
}

interface NewsItem {
  id: string;
  title: string;
  created_at: string;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({ residents: 0, properties: 0, activeVisits: 0, todayEntries: 0 });
  const [recentAccess, setRecentAccess] = useState<AccessLog[]>([]);
  const [recentNews, setRecentNews] = useState<NewsItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetch() {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const [residents, properties, visits, todayLogs, accessLogs, news] = await Promise.all([
        supabase.from("profiles").select("id", { count: "exact", head: true }),
        supabase.from("properties").select("id", { count: "exact", head: true }).eq("is_active", true),
        supabase.from("visits").select("id", { count: "exact", head: true }).eq("status", "active"),
        supabase.from("access_logs").select("id", { count: "exact", head: true }).gte("created_at", today.toISOString()),
        supabase.from("access_logs").select("id, visitor_name, action, method, created_at, properties(name)").order("created_at", { ascending: false }).limit(8),
        supabase.from("news").select("id, title, created_at").eq("is_published", true).order("created_at", { ascending: false }).limit(5),
      ]);

      setStats({
        residents: residents.count ?? 0,
        properties: properties.count ?? 0,
        activeVisits: visits.count ?? 0,
        todayEntries: todayLogs.count ?? 0,
      });
      setRecentAccess((accessLogs.data as any) ?? []);
      setRecentNews((news.data as any) ?? []);
      setLoading(false);
    }
    fetch();
  }, []);

  function timeAgo(d: string) {
    const diff = Date.now() - new Date(d).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return "just now";
    if (mins < 60) return mins + "m ago";
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return hrs + "h ago";
    return Math.floor(hrs / 24) + "d ago";
  }

  if (loading) return <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>;

  return (
    <div>
      <div style={{ marginBottom: 32 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Dashboard</h1>
        <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>Community overview</p>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16, marginBottom: 32 }}>
        <StatCard label="Residents" value={stats.residents} />
        <StatCard label="Properties" value={stats.properties} />
        <StatCard label="Active Visits" value={stats.activeVisits} />
        <StatCard label="Today's Entries" value={stats.todayEntries} />
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))", gap: 16 }}>
        <div className="nimbus-card" style={{ padding: 24 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, color: "var(--text-primary)", marginBottom: 16 }}>Recent Access</h2>
          {recentAccess.length === 0 ? (
            <p style={{ fontSize: 14, color: "var(--text-tertiary)" }}>No access logs yet.</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {recentAccess.map((log) => (
                <div key={log.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div>
                    <p style={{ fontSize: 14, fontWeight: 500, color: "var(--text-primary)" }}>{log.visitor_name}</p>
                    <p style={{ fontSize: 12, color: "var(--text-tertiary)" }}>{log.properties?.name ?? "—"} · {log.method}</p>
                  </div>
                  <span style={{ fontSize: 12, color: "var(--text-tertiary)", whiteSpace: "nowrap" }}>{timeAgo(log.created_at)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="nimbus-card" style={{ padding: 24 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, color: "var(--text-primary)", marginBottom: 16 }}>Latest News</h2>
          {recentNews.length === 0 ? (
            <p style={{ fontSize: 14, color: "var(--text-tertiary)" }}>No announcements yet.</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {recentNews.map((n) => (
                <div key={n.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <p style={{ fontSize: 14, fontWeight: 500, color: "var(--text-primary)" }}>{n.title}</p>
                  <span style={{ fontSize: 12, color: "var(--text-tertiary)", whiteSpace: "nowrap" }}>{timeAgo(n.created_at)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="nimbus-card" style={{ padding: 20 }}>
      <p style={{ fontSize: 13, color: "var(--text-secondary)", marginBottom: 6, fontWeight: 500 }}>{label}</p>
      <p style={{ fontSize: 28, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-1px", lineHeight: 1 }}>{value}</p>
    </div>
  );
}
