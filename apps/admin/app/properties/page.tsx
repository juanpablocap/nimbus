"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { Icon } from "@/components/ui/icon";

interface Property {
  id: string;
  name: string;
  property_type: string;
  address: string | null;
  is_active: boolean;
  created_at: string;
}

export default function PropertiesPage() {
  const [properties, setProperties] = useState<Property[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ name: "", property_type: "house", address: "" });
  const [saving, setSaving] = useState(false);

  async function fetchProperties() {
    setLoading(true);
    const { data } = await supabase
      .from("properties")
      .select("*")
      .order("created_at", { ascending: false });
    setProperties(data ?? []);
    setLoading(false);
  }

  useEffect(() => { fetchProperties(); }, []);

  function openCreate() {
    setForm({ name: "", property_type: "house", address: "" });
    setEditingId(null);
    setShowForm(true);
  }

  function openEdit(p: Property) {
    setForm({ name: p.name, property_type: p.property_type, address: p.address ?? "" });
    setEditingId(p.id);
    setShowForm(true);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    if (editingId) {
      await supabase.from("properties").update({
        name: form.name,
        property_type: form.property_type,
        address: form.address || null,
        updated_at: new Date().toISOString(),
      }).eq("id", editingId);
    } else {
      const { data: profile } = await supabase.from("profiles").select("community_id").single();
      await supabase.from("properties").insert({
        name: form.name,
        property_type: form.property_type,
        address: form.address || null,
        community_id: profile?.community_id,
      });
    }
    setSaving(false);
    setShowForm(false);
    fetchProperties();
  }

  async function handleDelete(id: string) {
    if (!confirm("Are you sure you want to delete this property?")) return;
    await supabase.from("properties").delete().eq("id", id);
    fetchProperties();
  }

  const filtered = properties.filter((p) =>
    p.name.toLowerCase().includes(search.toLowerCase()) ||
    (p.address ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const typeLabels: Record<string, string> = {
    house: "House",
    apartment: "Apartment",
    lot: "Lot",
    commercial: "Commercial",
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Properties</h1>
          <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>{properties.length} total</p>
        </div>
        <button onClick={openCreate} style={{
          display: "flex", alignItems: "center", gap: 6, padding: "9px 16px",
          background: "var(--accent)", color: "white", border: "none",
          borderRadius: "var(--radius-md)", fontSize: 14, fontWeight: 600, cursor: "pointer",
        }}>
          + Add Property
        </button>
      </div>

      {/* Search */}
      <div style={{ marginBottom: 16 }}>
        <input type="text" placeholder="Search properties..." value={search} onChange={(e) => setSearch(e.target.value)}
          style={{
            width: "100%", maxWidth: 360, padding: "9px 12px", fontSize: 14,
            background: "var(--bg-secondary)", border: "1px solid var(--border)",
            borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
          }}
        />
      </div>

      {/* Table */}
      {loading ? (
        <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>Loading...</p>
      ) : filtered.length === 0 ? (
        <div className="nimbus-card" style={{ padding: 32, textAlign: "center" }}>
          <p style={{ color: "var(--text-tertiary)", fontSize: 14 }}>
            {search ? "No properties match your search." : "No properties yet. Create your first one."}
          </p>
        </div>
      ) : (
        <div className="nimbus-card" style={{ overflow: "hidden" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border)" }}>
                <th style={thStyle}>Name</th>
                <th style={thStyle}>Type</th>
                <th style={thStyle}>Address</th>
                <th style={thStyle}>Status</th>
                <th style={{ ...thStyle, textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((p) => (
                <tr key={p.id} style={{ borderBottom: "1px solid var(--border)" }}>
                  <td style={tdStyle}>
                    <span style={{ fontWeight: 500, color: "var(--text-primary)" }}>{p.name}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{typeLabels[p.property_type] ?? p.property_type}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{ color: "var(--text-secondary)" }}>{p.address ?? "—"}</span>
                  </td>
                  <td style={tdStyle}>
                    <span style={{
                      display: "inline-block", padding: "2px 8px", fontSize: 12, fontWeight: 500,
                      borderRadius: 9999,
                      background: p.is_active ? "#dcfce7" : "#fee2e2",
                      color: p.is_active ? "#16a34a" : "#dc2626",
                    }}>
                      {p.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, textAlign: "right" }}>
                    <button onClick={() => openEdit(p)} style={actionBtn}>Edit</button>
                    <button onClick={() => handleDelete(p.id)} style={{ ...actionBtn, color: "var(--danger)" }}>Delete</button>
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
              {editingId ? "Edit Property" : "New Property"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Name *</label>
                <input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Lot 15, House A3" style={inputStyle} />
              </div>
              <div style={{ marginBottom: 14 }}>
                <label style={labelStyle}>Type</label>
                <select value={form.property_type} onChange={(e) => setForm({ ...form, property_type: e.target.value })}
                  style={inputStyle}>
                  <option value="house">House</option>
                  <option value="apartment">Apartment</option>
                  <option value="lot">Lot</option>
                  <option value="commercial">Commercial</option>
                </select>
              </div>
              <div style={{ marginBottom: 20 }}>
                <label style={labelStyle}>Address</label>
                <input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })}
                  placeholder="Optional" style={inputStyle} />
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

const thStyle: React.CSSProperties = {
  textAlign: "left", padding: "10px 16px", fontSize: 12, fontWeight: 600,
  textTransform: "uppercase", letterSpacing: "0.05em", color: "var(--text-tertiary)",
};

const tdStyle: React.CSSProperties = {
  padding: "12px 16px",
};

const labelStyle: React.CSSProperties = {
  display: "block", fontSize: 13, fontWeight: 500, color: "var(--text-secondary)", marginBottom: 6,
};

const inputStyle: React.CSSProperties = {
  width: "100%", padding: "9px 12px", fontSize: 14,
  background: "var(--bg-primary)", border: "1px solid var(--border)",
  borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
};

const actionBtn: React.CSSProperties = {
  background: "none", border: "none", fontSize: 13, fontWeight: 500,
  color: "var(--accent)", cursor: "pointer", padding: "4px 8px",
};
