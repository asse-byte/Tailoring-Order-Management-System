#!/usr/bin/env bash
set -e
echo "=== Testing Manager Login ==="
curl -s -X POST http://localhost:3003/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"gerant","password":"979BB1E79224@344838"}'
echo ""
echo "=== Testing Secretary Login ==="
curl -s -X POST http://localhost:3003/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"secretaire","password":"0D70F198540B@af62e8"}'
echo ""
echo "=== Testing Superadmin Login ==="
curl -s -X POST http://localhost:3003/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"superadmin","password":"CoutureMaster@2026!"}'
echo ""
