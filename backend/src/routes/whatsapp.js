const express = require('express');
const whatsappService = require('../services/whatsapp');
const { asyncH } = require('../util');

const router = express.Router();

// Get WhatsApp gateway status & logs
router.get('/status', asyncH(async (req, res) => {
  res.json(whatsappService.getStatus());
}));

// Test automatic WhatsApp message dispatch
router.post('/test', asyncH(async (req, res) => {
  const phone = req.body.phone || '+22300000000';
  const dummyOrder = {
    id: 'test-order-id',
    client_name: req.body.client_name || 'Client Test',
    client_phone: phone,
    garment_type: req.body.garment || 'Robe Sur Mesure',
    total: 50000,
    advance: 20000,
  };
  const result = await whatsappService.sendOrderReadyMessage(dummyOrder);
  res.json(result);
}));

module.exports = router;
