const path = require('path');
const { Jimp } = require(path.join(__dirname, '../backend/node_modules/jimp'));

async function test() {
  const src = path.join(__dirname, '../logo/lah-collection.jpeg');
  const img = await Jimp.read(src);
  console.log('Read success:', img.bitmap.width, 'x', img.bitmap.height);
  
  // Clone and resize to 192
  const icon192 = img.clone();
  icon192.contain({ w: 192, h: 192 });
  const out192 = path.join(__dirname, '../logo/test-192.png');
  await icon192.write(out192);
  console.log('Wrote test 192:', out192);
}

test().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
