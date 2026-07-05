const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Jimp = require('jimp');
const { asyncH } = require('../util');

const router = express.Router();

// Ensure uploads directory exists
const UPLOADS_DIR = path.join(__dirname, '../../uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Multer configuration: temp storage
const upload = multer({
  dest: path.join(__dirname, '../../uploads/temp'),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB limit
});

router.post('/', upload.single('file'), asyncH(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Aucun fichier fourni.' });
  }

  const tempPath = req.file.path;
  const originalName = req.file.originalname;
  const ext = path.extname(originalName).toLowerCase();
  const fileId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  
  const mainFilename = `${fileId}${ext}`;
  const mainPath = path.join(UPLOADS_DIR, mainFilename);
  const mainUrl = `/uploads/${mainFilename}`;

  const isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext);

  try {
    if (isImage) {
      // Image: compress, resize, generate thumbnail
      const thumbFilename = `thumb_${fileId}${ext}`;
      const thumbPath = path.join(UPLOADS_DIR, thumbFilename);
      const thumbUrl = `/uploads/${thumbFilename}`;

      // Jimp image processing
      const image = await Jimp.read(tempPath);
      
      // Main image: max width 800px, quality 80%
      if (image.getWidth() > 800) {
        await image.resize(800, Jimp.AUTO);
      }
      await image.quality(80).writeAsync(mainPath);

      // Thumbnail: max width 150px, quality 70%
      const thumbImage = await Jimp.read(tempPath);
      if (thumbImage.getWidth() > 150) {
        await thumbImage.resize(150, Jimp.AUTO);
      }
      await thumbImage.quality(70).writeAsync(thumbPath);

      // Clean up temp file
      try {
        fs.unlinkSync(tempPath);
      } catch (_) {}

      return res.status(201).json({
        url: mainUrl,
        thumb_url: thumbUrl,
      });
    } else {
      // Non-image (e.g. video): move to final location
      fs.renameSync(tempPath, mainPath);
      return res.status(201).json({
        url: mainUrl,
        thumb_url: null,
      });
    }
  } catch (error) {
    try {
      if (fs.existsSync(tempPath)) {
        fs.unlinkSync(tempPath);
      }
    } catch (_) {}
    console.error('File processing failed:', error);
    return res.status(500).json({ error: 'Échec du traitement du fichier.' });
  }
}));

module.exports = router;
