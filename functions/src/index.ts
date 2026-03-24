import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret, defineString } from 'firebase-functions/params';
import sgMail from '@sendgrid/mail';

initializeApp();

// Trigger: When a new event is created (either by admin or anonymously)
export const onPublicEventCreated = onDocumentCreated('events/{eventId}', async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() as Record<string, any>;
  const db = getFirestore();

  try {
    // Try to discover adminId from the first settings doc (if present)
    const settingsSnap = await db.collection('settings').limit(1).get();
    const adminId = settingsSnap.empty ? null : (settingsSnap.docs[0].get('admin_id') as string | null);

    // Build the admin message payload
    const messageDoc = {
      type: 'event_submission',
      event_id: snap.id,
      title: data.title ?? '',
      venue: data.venue ?? '',
      location: data.location ?? '',
      event_date: data.event_date ?? null,
      submitted_by: data.owner_id ?? 'public',
      admin_id: adminId,
      created_at: FieldValue.serverTimestamp(),
      is_read: false,
      // Preserve original event payload for context
      payload: data,
    };

    await db.collection('messages').add(messageDoc);
  } catch (err) {
    console.error('Failed to create admin message for event', err);
  }
});

// Secrets and params for email sending
const SENDGRID_API_KEY = defineSecret('SENDGRID_API_KEY');
const FROM_EMAIL = defineString('FROM_EMAIL'); // e.g., no-reply@yourdomain.com
const ADMIN_EMAILS = defineString('ADMIN_EMAILS'); // optional, comma-separated fallback
const SENDGRID_TEMPLATE_ID_SCORE_REQUEST = defineString('SENDGRID_TEMPLATE_ID_SCORE_REQUEST');

type PerformanceItem = {
  venueName: string;
  dateTime: { seconds: number; nanoseconds: number } | Date | any; // Firestore Timestamp-like
  city: string;
  region: string;
  country: string;
  ticketingLink?: string;
};

type RequesterInfo = {
  firstName: string;
  lastName: string;
  phone: string;
  email: string;
  address: string;
  specialInstructions?: string;
};

// Trigger: when a public user submits a score request
export const onPerformanceRequestCreated = onDocumentCreated(
  { document: 'performance_requests/{requestId}', secrets: [SENDGRID_API_KEY] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const db = getFirestore();
    const data = snap.data() as Record<string, any>;

    try {
      const works: string[] = Array.isArray(data.works) ? data.works : [];
      const conductor: string = data.conductor ?? '';
      const ensemble: string = data.ensemble ?? '';
      const performances: PerformanceItem[] = Array.isArray(data.performances) ? data.performances : [];
      const requester: RequesterInfo = data.requester ?? {};

      // Discover admin recipients from settings/contact, else fall back to ADMIN_EMAILS param
      const settingsDoc = await db.collection('settings').doc('contact').get();
      let adminRecipients: string[] = [];
      if (settingsDoc.exists) {
        const s = settingsDoc.data() as any;
        const single = (s?.recipientEmail || '').toString().trim();
        const multi = Array.isArray(s?.recipientEmails) ? s.recipientEmails as string[] : [];
        if (multi.length) adminRecipients = multi.filter((e) => !!e && e.includes('@'));
        else if (single) adminRecipients = [single];
      }
      if (!adminRecipients.length) {
        const envList = ADMIN_EMAILS.value()?.split(',').map((e) => e.trim()).filter((e) => e.includes('@')) ?? [];
        adminRecipients = envList;
      }

      const fromEmail = FROM_EMAIL.value()?.trim();
      if (!SENDGRID_API_KEY.value() || !fromEmail) {
        console.error('Email not configured. Missing SENDGRID_API_KEY or FROM_EMAIL');
        return;
      }

      sgMail.setApiKey(SENDGRID_API_KEY.value()!);

      const formatDate = (ts: any) => {
        try {
          // Handle Firestore Timestamp-like objects
          const d = ts?.toDate ? ts.toDate() : (ts?.seconds ? new Date(ts.seconds * 1000) : (ts instanceof Date ? ts : null));
          if (!d) return 'Not set';
          return d.toLocaleString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: '2-digit', hour: 'numeric', minute: '2-digit' });
        } catch {
          return 'Not set';
        }
      };
      // Build dynamic template data for SendGrid
      const worksText = works.length ? works.join(', ') : '(none)';
      const requesterFullName = `${requester?.firstName ?? ''} ${requester?.lastName ?? ''}`.trim();
      const templateId = (SENDGRID_TEMPLATE_ID_SCORE_REQUEST.value() || '').trim();

      if (!templateId) {
        console.error('Missing SENDGRID_TEMPLATE_ID_SCORE_REQUEST parameter');
      }

      const performancesForTemplate = performances.map((p, i) => ({
        n: i + 1,
        date: formatDate(p.dateTime),
        venue: p.venueName || '',
        city: p.city || '',
        region: p.region || '',
        country: p.country || '',
        location: [p.city, p.region, p.country].filter(Boolean).join(', '),
        ticketingLink: p.ticketingLink || '',
      }));

      const dynamicBase = {
        requestId: snap.id,
        ensemble,
        conductor,
        works,
        works_text: worksText,
        performances: performancesForTemplate,
        requester: {
          fullName: requesterFullName,
          firstName: requester?.firstName ?? '',
          lastName: requester?.lastName ?? '',
          email: requester?.email ?? '',
          phone: requester?.phone ?? '',
          address: requester?.address ?? '',
          specialInstructions: requester?.specialInstructions ?? '',
        },
        submittedAt: new Date().toISOString(),
      } as const;

      const msgUser = requester?.email && templateId ? {
        to: requester.email,
        from: fromEmail,
        replyTo: adminRecipients.length ? adminRecipients[0] : undefined,
        templateId,
        dynamicTemplateData: { ...dynamicBase, audience: 'user', is_admin: false },
      } : null;

      const msgAdmin = adminRecipients.length && templateId ? {
        to: adminRecipients,
        from: fromEmail,
        templateId,
        dynamicTemplateData: { ...dynamicBase, audience: 'admin', is_admin: true },
      } : null;

      const sendOps: Promise<any>[] = [];
      if (msgUser) sendOps.push(sgMail.send(msgUser as any));
      if (msgAdmin) sendOps.push(sgMail.send(msgAdmin as any));
      if (sendOps.length) await Promise.allSettled(sendOps);
    } catch (err) {
      console.error('Failed to send score request emails', err);
    }
  }
);

function escapeHtml(input: string): string {
  return (input || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function escapeAttr(input: string): string {
  // Very basic attribute escaping
  return escapeHtml(input).replace(/`/g, '&#096;');
}
