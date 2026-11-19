// The formatted editor's webview code (Milkdown) as one script and one stylesheet: out/webview/editor.js, .css.
const esbuild = require('esbuild');
const path = require('path');
esbuild.buildSync({
  entryPoints: [path.join(__dirname, '..', 'webview', 'editor.ts')],
  bundle: true, minify: true, format: 'iife', target: 'es2020', platform: 'browser',
  outfile: path.join(__dirname, '..', 'out', 'webview', 'editor.js'),
  loader: { '.svg': 'text', '.woff': 'dataurl', '.woff2': 'dataurl', '.ttf': 'dataurl' },
  logLevel: 'warning',
});
console.log('webview: out/webview/editor.js');
