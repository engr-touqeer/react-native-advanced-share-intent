const fs = require('fs');
const path = require('path');

const manifestPath = path.join(
  __dirname,
  '..',
  'node_modules',
  'react-native-safe-area-context',
  'android',
  'src',
  'main',
  'AndroidManifest.xml'
);

if (!fs.existsSync(manifestPath)) {
  process.exit(0);
}

const original = fs.readFileSync(manifestPath, 'utf8');
const patched = original.replace(
  /\s+package="com\.th3rdwave\.safeareacontext"/,
  ''
);

if (patched !== original) {
  fs.writeFileSync(manifestPath, patched);
  console.log('Patched react-native-safe-area-context AndroidManifest.xml');
}
