"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface Resident {
  id: string;
  full_name: string;
  phone: string | null;
  is_active: boolean;
  created_at: string;
  email?: string;
  properties?: { id: string; name: string }[];
}

export default function ResidentsPage() {
  const [residents, setResidents] = useState<Resident[]>([]);
  const [properties, setProperties] = useState<{ id: string; name: string }[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ full_name: "", phone: "", email: "", password: "", property_id: "" });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function fetchResidents() {
    setLoading(true);
    const { data: profiles } = await supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false });

    const { data: rp } = await supabase
      .from("resident_properties")
      .select("profile_id, property_id, properties(id, name)");

    const enriched = (profiles ?? []).map((p) => {
      const assignments = (rp ?? []).filter((r: any) => r.profile_id === p.id);
      return {
        ...p,
        properties: assignments.map((a: any) => a.properties).filter(Boolean),
      };
    });

    setResidents(enriched);
    setLoading(false);
  }

  async function fetchProperties() {
    const { data } = await supabase.from("properties").select("id, name").eq("is_active", true).order("name");
    setProperties(data ?? []);
  }

  useEffect(() => { fetchResidents(); fetchProperties(); }, []);

  function openCreate() {
    setForm({ full_name: "", phone: "", email: "", password: "", property_id: "" });
    setEditingId(null);
    setError("");
    setShowForm(true);
  }

  function openEdit(r: Resident) {
    setForm({ full_name: r.full_name, phone: r.phone ?? "", email: "", password: "", property_id: "" });
    setEditingId(r.id);
    setError("");
    setShowForm(true);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError("");

    try {
      if (editingId) {
        await supabase.from("profiles").update({
          full_name: form.full_name,
          phone: form.phone || null,
          updated_at: new Date().toISOString(),
        }).eq("id", editingId);
      } else {
        if (!form.email || !form.password) {
          setError("Email and password are required for new residents");
          setSaving(false);
          return;
        }

        const { data: profile } = await supabase.from("profiles").select("community_id").single();
        const communityId = profile?.community_id;

        const res = await fetch("/api/create-resident", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email: form.email,
            password: form.password,
            full_name: form.full_name,
            phone: form.phone || null,
            community_id: communityId,
            property_id: form.property_id || null,
          }),
        });

        const result = await res.json();
        if (!res.ok) throw new Error(result.error || "Failed to create resident");
      }

      setShowForm(false);
      fetchResidents();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(id: string, currentlyActive: boolean) {
    await supabase.from("profiles").update({
      is_active: !currentlyActive,
      updated_at: new Date().toISOString(),
    }).eq("id", id);
    fetchResidents();
  }

  const filtered = residents.filter((r) =>
    r.full_name.toLowerCase().includes(search.toLowerCase()) ||
    (r.phone ?? "").includes(search)
  );

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Residents</h1>
          <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{residents.length} total</p>
        </div>
        <button onClick={openCreate} style={{
          display: "flex", alignItems: "center", gap: 6, padding: "9px 16px",
          background: "var(--accent)", color: "white", border: "none",
          borderRadius: "var(--radius-md)", fontSize: 14, fontWeight: 600, cursor: "pointer",
        }}>+ Add Resident</button>
      </div>

      <div style={{ marginBottom: 16 }}>
        <input type="text" placeholder="Search residents..." value={search} onChange={(e) => setSearch(e.target.value)}
          style={{
            width: "100%", maxWidth: 360, padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }}
        />
      </div>

      {loading ? (
        <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>
      ) : filtered.length === 0 ? (
        <div className="nimbus-card" style={{ padding: 32, textAlign: "center" }}>
          <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>
            {search ? "No residents match your search." : "No residents yet."}
          </p>
        </div>
      ) : (
        <div className="nimbus-card" style={{ overflow: "hidden" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border)" }}>
                <th style={thStyle}>Name</th>
                <th style={thStyle}>Phone</th>
                <th style={thStyle}>Property</th>
                <th style={thStyle}>Status</th>
                <th style={{ ...thStyle, textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id} style={{ borderBottom: "1px solid var(--border)" }}>
                  <td style={tdStyle}>
                    <span style={{ fontWeight: 500, color: "var(--text-primary)" }}>{r.full_name}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{r.phone ?? "—"}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>
                      {r.properties && r.properties.length > 0
                        ? r.properties.map((p) => p.name).join(", ")
                        : "—"}
                    </span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      display: "inline-block", padding: "2px 8px", fontSize: 12, fontWeight: 500,
                      borderRadius: 9999,
                      background: r.is_active ? "#dcfce7" : "#fee2e2",
                      color: r.is_active ? "#16a34a" : "#dc2626",
                    }}>{r.is_active ? "Active" : "Inactive"}</span>
                  </td>
                  <td style={{ ...tdStyle, textAlign: "right" }}>
                    <button onClick={() => openEdit(r)} style={actionBtn}>Edit</button>
                    <button onClick={() => toggleActive(r.id, r.is_active)} style={actionBtn}>
                      {r.is_active ? "Deactivate" : "Activate"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal */}
      {showForm && (
        <div style={{
          position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)",
          display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100,
        }} onClick={() => setShowForm(false)}>
          <div style={{
            background: "var(--bg-card)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-lg)", padding: 24, width: "100%", maxWidth: 440,
            boxShadow: "var(--shadow-md)",
          }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ fontSize: 18, fontWeight: 700, color: "var(--text-primary)", marginBottom: 20 }}>
              {editingId ? "Edit Resident" : "New Resident"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Full Name *</label>
                <input required value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })}
                  placeholder="John Doe" style={inputStyle} />
              </div>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Phone</label>
                <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  placeholder="+54 381 555 1234" style={inputStyle} />
              </div>
              {!editingId && (
                <>
                  <div style={{ marginBottom: 14 }}>
                    <label style={labelStyle}>Email *</label>
                    <input type="email" required value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })}
                      placeholder="resident@email.com" style={inputStyle} />
                  </div>
                  <div style={{ marginBottom: 14 }}>
                    <label style={labelStyle}>Password *</label>
                    <input type="password" required value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })}
                      placeholder="Min 6 characters" style={inputStyle} />
                  </div>
                  <div style={{ marginBottom: 14 }}>
                    <label style={labelStyle}>Assign to Property</label>
                    <select value={form.property_id} onChange={(e) => setForm({ ...form, property_id: e.target.value })}
                      style={inputStyle}>
                      <option value="">None</option>
                      {properties.map((p) => (
                        <option key={p.id} value={p.id}>{p.name}</option>
                      ))}
                    </select>
                  </div>
                </>
              )}
              {error && (
                <div style={{
                  padding: "10px 12px", marginBottom: 14, fontSize: 13,
                  background: "#fee2e2", border: "1px solid #fca5a5",
                  borderRadius: "var(--radius-md)", color: "#dc2626",
                }}>{error}</div>
              )}
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

const thStyle: React.CSSProperties = {
  textAlign: "left", padding: "10px 16px", fontSize: 12, fontWeight: 600,
  textTransform: "uppercase", letterSpacing: "0.05em", color: "var(--text-tertiary)",
};
const tdStyle: React.CSSProperties = { padding: "12px 16px" };
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
