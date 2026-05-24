"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/components/auth-provider";

interface NewsItem {
  id: string;
  title: string;
  body: string;
  is_published: boolean;
  published_at: string | null;
  created_at: string;
}

export default function NewsPage() {
  const { user } = useAuth();
  const [news, setNews] = useState<NewsItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ title: "", body: "", is_published: false });
  const [saving, setSaving] = useState(false);

  async function fetchNews() {
    setLoading(true);
    const { data, error } = await supabase
      .from("news")
      .select("*")
      .order("created_at", { ascending: false });
    console.log("news fetch:", data, error);
    setNews(data ?? []);
    setLoading(false);
  }

  useEffect(() => { fetchNews(); }, []);

  function openCreate() {
    setForm({ title: "", body: "", is_published: false });
    setEditingId(null);
    setShowForm(true);
  }

  function openEdit(n: NewsItem) {
    setForm({ title: n.title, body: n.body, is_published: n.is_published });
    setEditingId(n.id);
    setShowForm(true);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    if (editingId) {
      await supabase.from("news").update({
        title: form.title,
        body: form.body,
        is_published: form.is_published,
        published_at: form.is_published ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      }).eq("id", editingId);
    } else {
      const { data: profile } = await supabase.from("profiles").select("community_id").single();
      await supabase.from("news").insert({
        title: form.title,
        body: form.body,
        is_published: form.is_published,
        published_at: form.is_published ? new Date().toISOString() : null,
        community_id: profile?.community_id,
        author_id: user?.id,
      });
    }
    setSaving(false);
    setShowForm(false);
    fetchNews();
  }

  async function handleDelete(id: string) {
    if (!confirm("Delete this news item?")) return;
    await supabase.from("news").delete().eq("id", id);
    fetchNews();
  }

  async function togglePublish(n: NewsItem) {
    await supabase.from("news").update({
      is_published: !n.is_published,
      published_at: !n.is_published ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    }).eq("id", n.id);
    fetchNews();
  }

  const filtered = news.filter((n) =>
    n.title.toLowerCase().includes(search.toLowerCase())
  );

  function formatDate(d: string) {
    return new Date(d).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  }

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>News</h1>
          <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{news.length} total</p>
        </div>
        <button onClick={openCreate} style={{
          display: "flex", alignItems: "center", gap: 6, padding: "9px 16px",
          background: "var(--accent)", color: "white", border: "none",
          borderRadius: "var(--radius-md)", fontSize: 14, fontWeight: 600, cursor: "pointer",
        }}>+ New Post</button>
      </div>

      <div style={{ marginBottom: 16 }}>
        <input type="text" placeholder="Search news..." value={search} onChange={(e) => setSearch(e.target.value)}
          style={{
            width: "100%", maxWidth: 360, padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }} />
      </div>

      {loading ? (
        <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>
      ) : filtered.length === 0 ? (
        <div className="nimbus-card" style={{ padding: 32, textAlign: "center" }}>
          <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>
            {search ? "No news match your search." : "No news yet. Create your first post."}
          </p>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {filtered.map((n) => (
            <div key={n.id} className="nimbus-card" style={{ padding: 20 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 8 }}>
                <div>
                  <h3 style={{ fontSize: 16, fontWeight: 600, color: "var(--text-primary)", marginBottom: 4 }}>{n.title}</h3>
                  <span style={{ fontSize: 12, color: "var(--text-tertiary)" }}>{formatDate(n.created_at)}</span>
                </div>
                <span style={{
                  display: "inline-block", padding: "2px 8px", fontSize: 12, fontWeight: 500,
                  borderRadius: 9999,
                  background: n.is_published ? "#dcfce7" : "#fef3c7",
                  color: n.is_published ? "#16a34a" : "#d97706",
                }}>{n.is_published ? "Published" : "Draft"}</span>
              </div>
              <p style={{ fontSize: 14, color: "var(--text-secondary)", lineHeight: 1.5, marginBottom: 12 }}>{n.body}</p>
              <div style={{ display: "flex", gap: 4 }}>
                <button onClick={() => togglePublish(n)} style={actionBtn}>
                  {n.is_published ? "Unpublish" : "Publish"}
                </button>
                <button onClick={() => openEdit(n)} style={actionBtn}>Edit</button>
                <button onClick={() => handleDelete(n.id)} style={{ ...actionBtn, color: "#dc2626" }}>Delete</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {showForm && (
        <div style={{
          position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)",
          display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100,
        }} onClick={() => setShowForm(false)}>
          <div style={{
            background: "var(--bg-card)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-lg)", padding: 24, width: "100%", maxWidth: 520,
            boxShadow: "var(--shadow-md)",
          }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ fontSize: 18, fontWeight: 700, color: "var(--text-primary)", marginBottom: 20 }}>
              {editingId ? "Edit Post" : "New Post"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Title *</label>
                <input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="Announcement title" style={inputStyle} />
              </div>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Body *</label>
                <textarea required value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })}
                  placeholder="Write the announcement content..."
                  rows={5}
                  style={{ ...inputStyle, resize: "vertical" }} />
              </div>
              <div style={{ marginBottom: 20 }}>
                <label style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 14, color: "var(--text-primary)", cursor: "pointer" }}>
                  <input type="checkbox" checked={form.is_published}
                    onChange={(e) => setForm({ ...form, is_published: e.target.checked })} />
                  Publish immediately
                </label>
              </div>
              <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
                <button type="button" onClick={() => setShowForm(false)} style={{
                  padding: "9px 16px", fontSize: 14, background: "var(--bg-secondary)",
                  border: "1px solid var(--border)", borderRadius: "var(--radius-md)",
                  color: "var(--text-primary)", cursor: "pointer",
                }}>Cancel</button>
                <button type="submit" disabled={saving} style={{
                  padding: "9px 16px", fontSize: 14, fontWeight: 600,
                  background: saving ? "var(--text-tertiary)" : "var(--accent)",
                  color: "white", border: "none", borderRadius: "var(--radius-md)",
                  cursor: saving ? "not-allowed" : "pointer",
                }}>{saving ? "Saving..." : editingId ? "Update" : "Create"}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

const labelStyle: React.CSSProperties = { display: "block", fontSize: 13, fontWeight: 500, color: "var(--text-secondary)", marginBottom: 6 };
const inputStyle: React.CSSProperties = {
  width: "100%", padding: "9px 12px", fontSize: 14,
  background: "var(--bg-primary)", border: "1px solid var(--border)",
  borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
};
const actionBtn: React.CSSProperties = {
  background: "none", border: "none", fontSize: 13, fontWeight: 500,
  color: "var(--accent)", cursor: "pointer", padding: "4px 8px",
};
