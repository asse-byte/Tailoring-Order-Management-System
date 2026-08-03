const express = require('express');
const whatsappService = require('../services/whatsapp');
const { managerOnly } = require('../middleware/auth');
const { asyncH, str } = require('../util');

const router = express.Router();

// Gateway status: whether automatic sending is actually configured, and what
// went out. Both roles — it carries no financial data, and the secretary is
// the one who marks orders ready.
router.get('/status', asyncH(async (req, res) => {
  res.json(whatsappService.getStatus());
}));

// Manager-only: once a provider is configured this really does send a message
// to whatever number is passed, so it is not something to leave open.
router.post('/test', managerOnly, asyncH(async (req, res) => {
  const phone = str(req.body.phone);
  if (!phone) return res.status(400).json({ error: 'Numéro de téléphone requis.' });

  const result = await whatsappService.sendOrderReadyMessage({
    id: null,
    client_name: str(req.body.client_name) || 'Client Test',
    client_phone: phone,
    garment_type: str(req.body.garment) || 'Robe Sur Mesure',
    total: 50000,
    advance: 20000,
  });
  res.json(result);
}));

module.exports = router;
