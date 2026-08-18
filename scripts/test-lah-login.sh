#!/usr/bin/env bash
set -e
echo "=== Testing LAH Manager Login ==="
curl -s -X POST http://localhost:3004/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"gerant","password":"D9E94C8D7CD6@140875"}'
echo ""
echo "=== Testing LAH Secretary Login ==="
curl -s -X POST http://localhost:3004/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"secretaire","password":"AA37361741FC@ab300b"}'
echo ""
echo "=== Testing Superadmin Login ==="
curl -s -X POST http://localhost:3004/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"superadmin","password":"CoutureMaster@2026!"}'
echo ""
