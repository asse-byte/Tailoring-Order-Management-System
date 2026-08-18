#!/usr/bin/env node
/**
 * Automatically generate high-quality PWA and mobile home-screen icons
 * from a shop logo image for Android (WebAPK) and iOS.
 *
 * Usage:
 *   node scripts/generate-pwa-icons.js <inputLogoPath> <targetWebDir>
 */

const fs = require('fs');
const path = require('path');
const { Jimp } = require(path.join(__dirname, '../backend/node_modules/jimp'));

async function generateIcons(inputLogoPath, targetWebDir) {
  if (!fs.existsSync(inputLogoPath)) {
    throw new Error(`Logo file not found: ${inputLogoPath}`);
  }
  if (!fs.existsSync(targetWebDir)) {
    fs.mkdirSync(targetWebDir, { recursive: true });
  }

  const iconsDir = path.join(targetWebDir, 'icons');
  if (!fs.existsSync(iconsDir)) {
    fs.mkdirSync(iconsDir, { recursive: true });
  }

  console.log(`[PWA Icons] Reading logo from: ${inputLogoPath}`);
  const baseImg = await Jimp.read(inputLogoPath);
  const { width: w, height: h } = baseImg.bitmap;
  console.log(`[PWA Icons] Original dimensions: ${w}x${h}`);

  // Sample corner pixel color for padding backgrounds
  const cornerColor = baseImg.getPixelColor(0, 0);

  // Helper to create square icon
  async function makeStandardIcon(size, destPath) {
    const canvas = new Jimp({ width: size, height: size, color: cornerColor });
    const scaled = baseImg.clone();
    scaled.contain({ w: size, h: size });
    canvas.composite(scaled, 0, 0);
    await canvas.write(destPath);
  }

  // Helper to create maskable icon with 15% safe-zone margin for Android
  async function makeMaskableIcon(size, destPath) {
    const canvas = new Jimp({ width: size, height: size, color: cornerColor });
    const innerSize = Math.round(size * 0.76); // 76% size leaves ~12% padding all around
    const offset = Math.round((size - innerSize) / 2);
    const scaled = baseImg.clone();
    scaled.contain({ w: innerSize, h: innerSize });
    canvas.composite(scaled, offset, offset);
    await canvas.write(destPath);
  }

  console.log(`[PWA Icons] Generating icons for: ${targetWebDir}`);

  // 1. Favicon (48x48)
  await makeStandardIcon(48, path.join(targetWebDir, 'favicon.png'));

  // 2. Apple Touch Icon (180x180)
  await makeStandardIcon(180, path.join(targetWebDir, 'apple-touch-icon.png'));

  // 3. Android PWA Icons (192 & 512)
  await makeStandardIcon(192, path.join(iconsDir, 'Icon-192.png'));
  await makeStandardIcon(512, path.join(iconsDir, 'Icon-512.png'));

  // 4. Android Maskable Icons (192 & 512 with safe-zone)
  await makeMaskableIcon(192, path.join(iconsDir, 'Icon-maskable-192.png'));
  await makeMaskableIcon(512, path.join(iconsDir, 'Icon-maskable-512.png'));

  console.log(`[PWA Icons] Generated all 6 PWA icon assets successfully.`);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('Usage: node generate-pwa-icons.js <logoPath> <targetWebDir>');
  process.exit(1);
}

generateIcons(path.resolve(args[0]), path.resolve(args[1])).catch(err => {
  console.error('[PWA Icons] Error:', err);
  process.exit(1);
});
