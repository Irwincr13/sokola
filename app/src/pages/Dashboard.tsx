import { useAuth } from '../auth/useAuth'

export function Dashboard() {
  const { user, signOut } = useAuth()

  return (
    <div>
      <nav className="topbar">
        <span className="logo">sokola</span>
        <span className="muted">{user?.email}</span>
        <button className="link" onClick={signOut}>
          Sign out
        </button>
      </nav>
      <main className="page">
        <h1>Dashboard</h1>
        <p className="muted">Cost forecaster coming soon.</p>
      </main>
    </div>
  )
}
