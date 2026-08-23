#!/usr/bin/env bash
set -e
echo "=== Testing Massakai Manager Login ==="
curl -s -X POST http://localhost:3005/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"gerant","password":"4EAD84E0356A@4d2bd1"}'
echo ""
echo "=== Testing Massakai Secretary Login ==="
curl -s -X POST http://localhost:3005/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"secretaire","password":"489D17E8E412@6dcdc8"}'
echo ""
echo "=== Testing Superadmin Login ==="
curl -s -X POST http://localhost:3005/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"superadmin","password":"CoutureMaster@2026!"}'
echo ""
