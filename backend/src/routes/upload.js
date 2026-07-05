const express = require('express');
const multer = require('multer');
const path = require('path');
const os = require('os');
const fs = require('fs');
const { Jimp } = require('jimp');
const { asyncH } = require('../util');

const router = express.Router();

// Only shop media is accepted: product/model photos and model videos.
// Anything else (html, scripts, executables…) is rejected — /uploads is
// served statically, so an open whitelist would allow hosting arbitrary
// files on the shop's domain.
const IMAGE_EXTS = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
const VIDEO_EXTS = ['.mp4', '.mov', '.webm', '.m4v'];

const UPLOADS_DIR = path.join(__dirname, '../../uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Multer buffers into the OS temp dir — NOT under /uploads, which is public.
const upload = multer({
  dest: path.join(os.tmpdir(), 'couture-uploads'),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
});

router.post('/', upload.single('file'), asyncH(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Aucun fichier fourni.' });
  }

  const tempPath = req.file.path;
  const ext = path.extname(req.file.originalname).toLowerCase();
  const isImage = IMAGE_EXTS.includes(ext);
  const isVideo = VIDEO_EXTS.includes(ext);

  if (!isImage && !isVideo) {
    try { fs.unlinkSync(tempPath); } catch (_) { /* best effort */ }
    return res.status(400).json({
      error: `Type de fichier non autorisé (images: ${IMAGE_EXTS.join(', ')}; vidéos: ${VIDEO_EXTS.join(', ')}).`,
    });
  }

  const fileId = `${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
  const mainFilename = `${fileId}${ext}`;
  const mainPath = path.join(UPLOADS_DIR, mainFilename);
  const mainUrl = `/uploads/${mainFilename}`;

  try {
    if (isImage) {
      // Speed rule: compress + resize, and produce a thumbnail for lists.
      // Buffer-based Jimp calls only: the path-based read/write helpers rely
      // on dynamic import(), which the Jest VM refuses.
      const MIME = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp',
        '.gif': 'image/gif',
      };
      const source = fs.readFileSync(tempPath);

      const image = await Jimp.fromBuffer(source);
      if (image.width > 800) image.resize({ w: 800 });
      fs.writeFileSync(mainPath, await image.getBuffer(MIME[ext], { quality: 80 }));

      const thumbFilename = `thumb_${fileId}${ext}`;
      const thumb = await Jimp.fromBuffer(source);
      if (thumb.width > 150) thumb.resize({ w: 150 });
      fs.writeFileSync(
        path.join(UPLOADS_DIR, thumbFilename),
        await thumb.getBuffer(MIME[ext], { quality: 70 }));

      try { fs.unlinkSync(tempPath); } catch (_) { /* best effort */ }
      return res.status(201).json({
        url: mainUrl,
        thumb_url: `/uploads/${thumbFilename}`,
      });
    }

    // Video: stored as-is (rename can fail across devices → copy fallback).
    try {
      fs.renameSync(tempPath, mainPath);
    } catch (_) {
      fs.copyFileSync(tempPath, mainPath);
      fs.unlinkSync(tempPath);
    }
    return res.status(201).json({ url: mainUrl, thumb_url: null });
  } catch (error) {
    try {
      if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
    } catch (_) { /* best effort */ }
    console.error('File processing failed:', error);
    return res.status(500).json({ error: 'Échec du traitement du fichier.' });
  }
}));

module.exports = router;
