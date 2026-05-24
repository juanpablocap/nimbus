export default function DashboardPage() {
  return (
    <div>
      <div style={{ marginBottom: 32 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-0.5px", marginBottom: 4 }}>Dashboard</h1>
        <p style={{ fontSize: 14, color: "var(--text-secondary)" }}>Community overview</p>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 16, marginBottom: 32 }}>
        <StatCard label="Residents" value="—" />
        <StatCard label="Properties" value="—" />
        <StatCard label="Active Visits" value="—" />
        <StatCard label="Today's Entries" value="—" />
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))", gap: 16 }}>
        <div className="nimbus-card" style={{ padding: 24 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, color: "var(--text-primary)", marginBottom: 16 }}>Recent Access</h2>
          <p style={{ fontSize: 14, color: "var(--text-tertiary)" }}>No access logs yet.</p>
        </div>
        <div className="nimbus-card" style={{ padding: 24 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, color: "var(--text-primary)", marginBottom: 16 }}>Latest News</h2>
          <p style={{ fontSize: 14, color: "var(--text-tertiary)" }}>No announcements yet.</p>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="nimbus-card" style={{ padding: 20 }}>
      <p style={{ fontSize: 13, color: "var(--text-secondary)", marginBottom: 6, fontWeight: 500 }}>{label}</p>
      <p style={{ fontSize: 28, fontWeight: 700, color: "var(--text-primary)", letterSpacing: "-1px", lineHeight: 1 }}>{value}</p>
    </div>
  );
}
