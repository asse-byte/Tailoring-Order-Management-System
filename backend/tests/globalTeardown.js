const fs = require('fs');

module.exports = async () => {
  if (globalThis.__EPG__) {
    await globalThis.__EPG__.stop();
  }
  if (globalThis.__EPG_DIR__) {
    try {
      fs.rmSync(globalThis.__EPG_DIR__, { recursive: true, force: true });
    } catch { /* best effort */ }
  }
};
