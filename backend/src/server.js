const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { createApp } = require('./app');

for (const key of ['DATABASE_URL', 'JWT_SECRET']) {
  if (!process.env[key]) {
    console.error(`Missing required env var: ${key}`);
    process.exit(1);
  }
}

const port = Number(process.env.PORT) || 3000;
createApp().listen(port, () => {
  console.log(`Rayan Couture API listening on :${port}`);
});
