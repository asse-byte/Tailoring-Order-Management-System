#!/usr/bin/env bash
set -e

echo "=== Cleaning ONLY yatt-services database ==="

# 1. Truncate business data tables in yatt-services
docker compose -f /srv/yatt-services/docker-compose.yml exec -T db psql -U couture -d couture_mali << 'EOF'
TRUNCATE TABLE
  appointments,
  client_measurements,
  order_item_corrections,
  order_items,
  order_payment_corrections,
  order_payments,
  orders,
  clients,
  sale_corrections,
  sales,
  product_images,
  products,
  model_media,
  pret_a_porter_models,
  entry_corrections,
  tailor_daily_entries,
  salary_payment_corrections,
  salary_payments,
  staff_pay_history,
  staff_pay,
  staff,
  expense_corrections,
  expenses,
  supplier_payment_corrections,
  supplier_payments,
  supplier_purchases,
  suppliers,
  wholesale_payment_corrections,
  wholesale_payments,
  wholesale_orders
CASCADE;
EOF

echo "=== Checking preserved tables (users & settings) ==="
docker compose -f /srv/yatt-services/docker-compose.yml exec -T db psql -U couture -d couture_mali -c "SELECT id, username, name, role FROM users;"
docker compose -f /srv/yatt-services/docker-compose.yml exec -T db psql -U couture -d couture_mali -c "SELECT * FROM settings;"

echo "=== Cleaning uploads folder (preserving logo) ==="
docker compose -f /srv/yatt-services/docker-compose.yml exec -T api sh -c 'find /app/uploads -type f ! -name "yatt_services_logo.jpg" -delete'
docker compose -f /srv/yatt-services/docker-compose.yml exec -T api ls -la /app/uploads

echo "=== yatt-services is now completely clean and ready for client delivery! ==="
