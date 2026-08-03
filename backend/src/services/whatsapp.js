// =============================================================================
// WhatsApp dispatch — "order ready" notifications.
// =============================================================================
// IMPORTANT, read before changing anything here.
//
// WhatsApp messages can only be sent programmatically through a paid provider
// account (Meta Cloud API, UltraMsg, Green API, Twilio…). There is no way for
// a server to push a WhatsApp message without one.
//
// This service therefore only really sends when a provider IS configured
// through the environment. When it is not, it reports `not_configured` and
// sends NOTHING. It must never report success for a message that was not
// handed to a provider: the shop reads "client notified" and stops calling
// people, so a comfortable lie here costs a real customer a real order.
//
// The customer-facing WhatsApp flow the shops actually use today is the
// client-side wa.me link on the order screen, which opens the conversation
// with a prefilled message. That one works without any provider account.
//
// To enable real automatic sending, set in the shop's .env:
//   WHATSAPP_PROVIDER=ultramsg|greenapi
//   WHATSAPP_INSTANCE_ID=<instance id>
//   WHATSAPP_API_KEY=<token>
// =============================================================================

const db = require('../db');

/**
 * Normalise a phone number to international format.
 * Local Malian numbers are 8 digits and get the 223 country code.
 */
function normalizePhone(rawPhone) {
  if (!rawPhone) return null;
  let cleaned = String(rawPhone).replace(/[^\d+]/g, '');
  if (!cleaned) return null;
  if (!cleaned.startsWith('+')) {
    cleaned = cleaned.length === 8 ? `+223${cleaned}` : `+${cleaned}`;
  }
  return cleaned;
}

/** The French "your order is ready" message. */
function buildReadyMessage(order, shopName) {
  const clientName = order.client_name || 'Client(e)';
  const garment = order.garment_type || 'vêtement';
  const total = Number(order.total) || 0;
  const advance = Number(order.advance) || 0;
  const reste = Math.max(0, total - advance);
  const resteFormatted = `${new Intl.NumberFormat('fr-FR').format(reste)} FCFA`;

  return `Bonjour ${clientName},\n\n`
    + `Bonne nouvelle ! Votre commande (${garment}) chez ${shopName} est prête pour retrait !\n\n`
    + `Reste à régler: ${resteFormatted}\n`
    + `Vous pouvez passer la récupérer à l'atelier à tout moment.\n\n`
    + `Merci beaucoup pour votre patience et votre confiance !`;
}

class WhatsAppService {
  constructor() {
    this.provider = (process.env.WHATSAPP_PROVIDER || '').trim().toLowerCase();
    this.apiKey = process.env.WHATSAPP_API_KEY || '';
    this.instanceId = process.env.WHATSAPP_INSTANCE_ID || '';
    this.logs = [];
  }

  /** True only when a provider AND its credentials are actually present. */
  get configured() {
    return Boolean(this.provider && this.apiKey && this.instanceId);
  }

  /** Shop name from settings, falling back to the env value. */
  async shopName() {
    try {
      const { rows } = await db.query(
        "SELECT value #>> '{}' AS shop_name FROM settings WHERE key = 'shop_name'");
      if (rows[0] && rows[0].shop_name) return rows[0].shop_name;
    } catch (_) { /* settings unavailable — fall through */ }
    return process.env.SHOP_NAME || 'Notre atelier';
  }

  /** POST to the configured provider. Throws if the provider rejects. */
  async dispatch(phone, text) {
    const endpoints = {
      ultramsg: {
        url: `https://api.ultramsg.com/${this.instanceId}/messages/chat`,
        body: { token: this.apiKey, to: phone, body: text },
      },
      greenapi: {
        url: `https://api.green-api.com/waInstance${this.instanceId}/sendMessage/${this.apiKey}`,
        body: { chatId: `${phone.replace('+', '')}@c.us`, message: text },
      },
    };
    const cfg = endpoints[this.provider];
    if (!cfg) throw new Error(`Fournisseur WhatsApp inconnu: ${this.provider}`);

    const res = await fetch(cfg.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(cfg.body),
    });
    if (!res.ok) throw new Error(`Fournisseur ${this.provider} a répondu ${res.status}`);
    return res.json().catch(() => ({}));
  }

  /**
   * Notify a client that their order is ready.
   * Always resolves with {sent, reason} — never throws — so a notification
   * problem can never fail the order update that triggered it.
   */
  async sendOrderReadyMessage(order) {
    const phone = normalizePhone(order && order.client_phone);
    if (!phone) return { sent: false, reason: 'missing_phone' };

    if (!this.configured) {
      // Deliberately not an error: most shops run without a provider and use
      // the wa.me button instead. Say plainly that nothing was sent.
      return { sent: false, reason: 'not_configured', phone };
    }

    const text = buildReadyMessage(order, await this.shopName());
    const entry = { order_id: order.id, phone, sent_at: new Date().toISOString() };
    try {
      await this.dispatch(phone, text);
      this.logs.unshift({ ...entry, status: 'SENT' });
      if (this.logs.length > 50) this.logs.pop();
      return { sent: true, phone };
    } catch (err) {
      this.logs.unshift({ ...entry, status: 'FAILED', error: err.message });
      if (this.logs.length > 50) this.logs.pop();
      return { sent: false, reason: 'provider_error', error: err.message, phone };
    }
  }

  getStatus() {
    return {
      configured: this.configured,
      provider: this.provider || null,
      // French: this string is shown in the manager's settings screen.
      detail: this.configured
        ? 'Envoi automatique actif.'
        : "Envoi automatique inactif : aucun fournisseur WhatsApp configuré. "
          + "Utilisez le bouton WhatsApp de la commande pour prévenir le client.",
      total_sent: this.logs.filter((l) => l.status === 'SENT').length,
      recent_logs: this.logs.slice(0, 10),
    };
  }
}

module.exports = new WhatsAppService();
module.exports.normalizePhone = normalizePhone;
module.exports.buildReadyMessage = buildReadyMessage;
