import path from 'path';

import react from '@vitejs/plugin-react';

export default {
  publicDir: './static',
  plugins: [react()],
  build: {
    target: 'es2018',
    format: 'esm',
    minify: false,
    outDir: '../priv/static',
    emptyOutDir: true,
    assetsInlineLimit: 0,
    rollupOptions: {
      input: ['app.tsx'],
      output: {
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name][extname]',
      },
      onwarn(warning, warn) {
        if (warning.code === 'MODULE_LEVEL_DIRECTIVE') {
          return;
        }
        warn(warning);
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'js'),
    },
  },
};
