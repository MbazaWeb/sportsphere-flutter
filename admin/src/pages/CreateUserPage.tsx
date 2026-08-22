import { useEffect, useState } from 'react'
import { adminCreateUser } from '../lib/api'
import { ALL_ROLES, ROLE_CONFIGS, type RoleFieldDef } from '../lib/supabase'

export function CreateUserPage() {
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)

  // Common fields
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [handle, setHandle] = useState('')
  const [country, setCountry] = useState('')
  const [bio, setBio] = useState('')
  const [role, setRole] = useState('fan')

  // Role-specific fields
  const [roleFields, setRoleFields] = useState<Record<string, string>>({})

  const selectedConfig = ROLE_CONFIGS[role]
  const hasRoleForm = selectedConfig && selectedConfig.fields.length > 0

  useEffect(() => {
    // Reset role fields when role changes
    setRoleFields({})
  }, [role])

  function setRoleField(key: string, value: string) {
    setRoleFields((prev) => ({ ...prev, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!email || !password || !firstName || !handle) {
      setErr('Email, password, first name, and handle are required')
      return
    }
    if (password.length < 6) {
      setErr('Password must be at least 6 characters')
      return
    }

    setCreating(true)
    setErr(null)
    setMsg(null)

    try {
      // Build role-specific profile data, converting types
      const profileData: Record<string, any> = {}
      if (selectedConfig) {
        for (const field of selectedConfig.fields) {
          const val = roleFields[field.key]
          if (val !== undefined && val !== '') {
            if (field.type === 'number') {
              profileData[field.key] = parseFloat(val) || null
            } else if (field.type === 'tags') {
              profileData[field.key] = val.split(',').map((s) => s.trim()).filter(Boolean)
            } else {
              profileData[field.key] = val
            }
          }
        }
      }

      const result = await adminCreateUser({
        email,
        password,
        firstName,
        lastName,
        handle: handle.replace(/^@/, ''),
        role,
        country: country || undefined,
        bio: bio || undefined,
        profileData: Object.keys(profileData).length > 0 ? profileData : undefined,
      })

      setMsg(`Created user: @${result.handle} (${result.role}) [${result.userId.slice(0, 8)}...]`)

      // Reset form
      setEmail('')
      setPassword('')
      setFirstName('')
      setLastName('')
      setHandle('')
      setCountry('')
      setBio('')
      setRoleFields({})
    } catch (e: any) {
      setErr(e.message || 'Failed to create user')
    } finally {
      setCreating(false)
    }
  }

  // Group roles by category
  const individualRoles = ALL_ROLES.filter((r) => r.category === 'individual')
  const orgRoles = ALL_ROLES.filter((r) => r.category === 'organization')
  const commerceRoles = ALL_ROLES.filter((r) => r.category === 'commerce')

  return (
    <div>
      <h1 className="page-title">Create User</h1>
      <p className="page-sub">
        Create a new user account with a dedicated role-based profile. Each role has
        specific fields matching the database schema.
      </p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <form onSubmit={handleSubmit}>
        {/* ── Common Account Fields ─────────────────────────── */}
        <div className="card" style={{ marginBottom: 18 }}>
          <h3 style={{ marginBottom: 12, color: 'var(--text)', fontSize: 15, fontWeight: 600 }}>
            Account Information
          </h3>
          <div className="grid grid-2" style={{ gap: 12 }}>
            <div className="stack">
              <label className="field-label">First Name *</label>
              <input
                className="input"
                placeholder="e.g. John"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                required
              />
            </div>
            <div className="stack">
              <label className="field-label">Last Name</label>
              <input
                className="input"
                placeholder="e.g. Doe"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
              />
            </div>
            <div className="stack">
              <label className="field-label">Email *</label>
              <input
                className="input"
                type="email"
                placeholder="user@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div className="stack">
              <label className="field-label">Password * (min 6 chars)</label>
              <input
                className="input"
                type="password"
                placeholder="Min 6 characters"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
              />
            </div>
            <div className="stack">
              <label className="field-label">Handle * (unique)</label>
              <input
                className="input"
                placeholder="e.g. john_doe"
                value={handle}
                onChange={(e) => setHandle(e.target.value.replace(/[^a-z0-9_]/gi, '').toLowerCase())}
                required
              />
            </div>
            <div className="stack">
              <label className="field-label">Country</label>
              <input
                className="input"
                placeholder="e.g. Tanzania"
                value={country}
                onChange={(e) => setCountry(e.target.value)}
              />
            </div>
          </div>
          <div className="stack" style={{ marginTop: 12 }}>
            <label className="field-label">Bio</label>
            <textarea
              className="textarea"
              placeholder="Brief bio for the profile..."
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              style={{ minHeight: 70 }}
            />\n          </div>
        </div>

        {/* ── Role Selection ────────────────────────────────── */}
        <div className="card" style={{ marginBottom: 18 }}>
          <h3 style={{ marginBottom: 12, color: 'var(--text)', fontSize: 15, fontWeight: 600 }}>
            Role Assignment
          </h3>
          <p className="muted" style={{ marginBottom: 12, fontSize: 12 }}>
            Select the role for this user. Each role activates a dedicated profile form below.
          </p>

          <div className="grid grid-3" style={{ gap: 12, marginBottom: hasRoleForm ? 18 : 0 }}>
            <div className="stack">
              <label className="field-label">Individual Roles</label>
              <select
                className="select"
                value={individualRoles.find((r) => r.value === role) ? role : ''}
                onChange={(e) => setRole(e.target.value)}
              >
                <option value="">Select...</option>
                {individualRoles.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="stack">
              <label className="field-label">Organization Roles</label>
              <select
                className="select"
                value={orgRoles.find((r) => r.value === role) ? role : ''}
                onChange={(e) => setRole(e.target.value)}
              >
                <option value="">Select...</option>
                {orgRoles.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="stack">
              <label className="field-label">Commerce Roles</label>
              <select
                className="select"
                value={commerceRoles.find((r) => r.value === role) ? role : ''}
                onChange={(e) => setRole(e.target.value)}
              >
                <option value="">Select...</option>
                {commerceRoles.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Currently selected role badge */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="muted" style={{ fontSize: 12 }}>Selected:</span>
            <span className="badge ok" style={{ textTransform: 'capitalize' }}>
              {role}
            </span>
            {hasRoleForm && (
              <span className="muted" style={{ fontSize: 11 }}>
                → {selectedConfig.table} ({selectedConfig.fields.length} fields)
              </span>
            )}
          </div>
        </div>

        {/* ── Role-Specific Profile Form ────────────────────── */}
        {hasRoleForm && (
          <div className="card" style={{ marginBottom: 18, borderColor: 'rgba(22, 140, 255, 0.25)' }}>
            <h3 style={{
              marginBottom: 12, color: 'var(--blue)', fontSize: 15, fontWeight: 600,
              display: 'flex', alignItems: 'center', gap: 8
            }}>
              <span style={{ fontSize: 18 }}>{ALL_ROLES.find((r) => r.value === role)?.label === 'Fan' ? '👤' : ''}</span>
              {role.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())} Profile
              <span className="muted" style={{ fontSize: 11, fontWeight: 400 }}>
                Table: {selectedConfig.table}
              </span>
            </h3>
            <div className="grid grid-2" style={{ gap: 12 }}>
              {selectedConfig.fields.map((field) => (
                <RoleFieldInput
                  key={field.key}
                  field={field}
                  value={roleFields[field.key] || ''}
                  onChange={(val) => setRoleField(field.key, val)}
                />
              ))}
            </div>
          </div>
        )}

        {!hasRoleForm && role !== 'fan' && (
          <div className="card" style={{ marginBottom: 18, opacity: 0.6 }}>
            <p className="muted">No dedicated profile form for this role.</p>
          </div>
        )}

        {role === 'fan' && (
          <div className="card" style={{ marginBottom: 18, opacity: 0.6 }}>
            <p className="muted">
              Fan is the default role — no additional profile fields needed. The user will
              be able to follow teams, vote on polls, make predictions, and join communities.
            </p>
          </div>
        )}

        {/* ── Submit ──────────────────────────────────────────── */}
        <div className="row" style={{ justifyContent: 'flex-end', gap: 12 }}>
          <button type="button" className="btn" onClick={() => {
            setEmail(''); setPassword(''); setFirstName(''); setLastName('');
            setHandle(''); setCountry(''); setBio(''); setRoleFields({});
            setMsg(null); setErr(null);
          }}>
            Reset
          </button>
          <button
            type="submit"
            className="btn btn-primary"
            disabled={creating}
            style={{ minWidth: 160 }}
          >
            {creating ? 'Creating...' : `Create ${role.replace(/_/g, ' ')} Account`}
          </button>
        </div>
      </form>
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════
// ROLE FIELD INPUT COMPONENT
// ═══════════════════════════════════════════════════════════════

function RoleFieldInput({
  field,
  value,
  onChange,
}: {
  field: RoleFieldDef
  value: string
  onChange: (val: string) => void
}) {
  if (field.type === 'select') {
    return (
      <div className="stack">
        <label className="field-label">
          {field.label}
          {field.required && <span style={{ color: 'var(--red)' }}> *</span>}
        </label>
        <select
          className="select"
          value={value}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">{field.placeholder || 'Select...'}</option>
          {field.options?.map((opt) => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>
      </div>
    )
  }

  if (field.type === 'textarea') {
    return (
      <div className="stack" style={{ gridColumn: '1 / -1' }}>
        <label className="field-label">
          {field.label}
          {field.required && <span style={{ color: 'var(--red)' }}> *</span>}
        </label>
        <textarea
          className="textarea"
          placeholder={field.placeholder}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          style={{ minHeight: 80 }}
        />
      </div>
    )
  }

  if (field.type === 'tags') {
    return (
      <div className="stack" style={{ gridColumn: '1 / -1' }}>
        <label className="field-label">
          {field.label}
          {field.required && <span style={{ color: 'var(--red)' }}> *</span>}
        </label>
        <input
          className="input"
          placeholder={field.placeholder || 'Comma-separated values'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
        <span className="muted" style={{ fontSize: 11 }}>Comma-separated values</span>
      </div>
    )
  }

  return (
    <div className="stack">
      <label className="field-label">
        {field.label}
        {field.required && <span style={{ color: 'var(--red)' }}> *</span>}
      </label>
      <input
        className="input"
        type={field.type === 'number' ? 'number' : field.type === 'date' ? 'date' : 'text'}
        placeholder={field.placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={field.required}
        min={field.type === 'number' ? '0' : undefined}
      />
    </div>
  )
}
