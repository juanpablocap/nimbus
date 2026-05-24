"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { signIn } from "@/lib/auth";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await signIn(email, password);
      router.push("/");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center",
      background: "var(--bg-primary)", padding: 20,
    }}>
      <div style={{
        width: "100%", maxWidth: 400, background: "var(--bg-card)",
        border: "1px solid var(--border)", borderRadius: "var(--radius-lg)",
        padding: 32, boxShadow: "var(--shadow-md)",
      }}>
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div style={{
            width: 48, height: 48, background: "var(--accent)", borderRadius: "var(--radius-md)",
            display: "flex", alignItems: "center", justifyContent: "center",
            color: "white", fontWeight: 700, fontSize: 24, margin: "0 auto 12px",
          }}>N</div>
          <h1 style={{ fontSize: 22, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px" }}>
            Nimbus Admin
          </h1>
          <p style={{ fontSize: 14, color: "var(--text-secondary)", marginTop: 4 }}>
            Sign in to your account
          </p>
        </div>

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: "block", fontSize: 13, fontWeight: 500, color: "var(--text-secondary)", marginBottom: 6 }}>
              Email
            </label>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required
              placeholder="admin@nimbus.app"
              style={{
                width: "100%", padding: "10px 12px", fontSize: 14,
                background: "var(--bg-primary)", border: "1px solid var(--border)",
                borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
              }}
            />
          </div>

          <div style={{ marginBottom: 24 }}>
            <label style={{ display: "block", fontSize: 13, fontWeight: 500, color: "var(--text-secondary)", marginBottom: 6 }}>
              Password
            </label>
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required
              placeholder="••••••••"
              style={{
                width: "100%", padding: "10px 12px", fontSize: 14,
                background: "var(--bg-primary)", border: "1px solid var(--border)",
                borderRadius: "var(--radius-md)", color: "var(--text-primary)", outline: "none",
              }}
            />
          </div>

          {error && (
            <div style={{
              padding: "10px 12px", marginBottom: 16, fontSize: 13,
              background: "#fee2e2", border: "1px solid #fca5a5",
              borderRadius: "var(--radius-md)", color: "#dc2626",
            }}>
              {error}
            </div>
          )}

          <button type="submit" disabled={loading}
            style={{
              width: "100%", padding: "10px 16px", fontSize: 14, fontWeight: 600,
              background: loading ? "var(--text-tertiary)" : "var(--accent)",
              color: "white", border: "none", borderRadius: "var(--radius-md)",
              cursor: loading ? "not-allowed" : "pointer",
            }}>
            {loading ? "Signing in..." : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}
