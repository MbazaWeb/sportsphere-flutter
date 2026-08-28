// vps/api/src/lib/email.ts
// Email delivery via Resend API (primary) with SMTP fallback.
// Configure in .env:
//   RESEND_API_KEY=re_...          ← get from resend.com (free: 3000/month)
//   EMAIL_FROM=noreply@playifysport.fun
//
// Resend free tier: 3,000 emails/month, 100/day — plenty for password resets.

interface EmailPayload {
  to:      string
  subject: string
  html:    string
  text?:   string
}

/** Send email via Resend API. Returns true on success. */
async function sendViaResend(payload: EmailPayload): Promise<boolean> {
  const apiKey = Bun.env.RESEND_API_KEY
  if (!apiKey) return false

  const from = Bun.env.EMAIL_FROM ?? 'Playify <noreply@playifysport.fun>'

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      from,
      to:      [payload.to],
      subject: payload.subject,
      html:    payload.html,
      text:    payload.text ?? payload.html.replace(/<[^>]*>/g, ''),
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    console.error('[Email/Resend] Failed:', err)
    return false
  }

  const data = await res.json() as { id?: string }
  console.log('[Email/Resend] Sent:', data.id)
  return true
}

/** Send email via SMTP using Bun's built-in fetch (Mailgun/SendGrid compatible). */
async function sendViaSMTP(payload: EmailPayload): Promise<boolean> {
  const smtpUrl = Bun.env.SMTP_URL // e.g. smtp://user:pass@smtp.gmail.com:587
  if (!smtpUrl) return false

  // Mailgun API (if MAILGUN_API_KEY set)
  const mailgunKey    = Bun.env.MAILGUN_API_KEY
  const mailgunDomain = Bun.env.MAILGUN_DOMAIN ?? 'playifysport.fun'
  if (mailgunKey) {
    const form = new FormData()
    form.append('from', Bun.env.EMAIL_FROM ?? 'noreply@playifysport.fun')
    form.append('to', payload.to)
    form.append('subject', payload.subject)
    form.append('html', payload.html)

    const res = await fetch(`https://api.mailgun.net/v3/${mailgunDomain}/messages`, {
      method: 'POST',
      headers: { 'Authorization': `Basic ${btoa(`api:${mailgunKey}`)}` },
      body: form,
    })
    return res.ok
  }

  return false
}

/** Main send function — tries Resend first, then SMTP fallback. */
export async function sendEmail(payload: EmailPayload): Promise<boolean> {
  // Try Resend
  if (await sendViaResend(payload)) return true
  // Try SMTP/Mailgun
  if (await sendViaSMTP(payload)) return true
  // Both failed
  return false
}
