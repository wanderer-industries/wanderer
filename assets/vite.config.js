import cdn from 'vite-plugin-cdn-import';
import path from 'path';

export default {
  publicDir: './static',
  plugins: [
    cdn({
      modules: [
        {
          name: 'react',
          var: 'React',
          path: `umd/react.production.min.js`,
        },
        {
          name: 'react-dom',
          var: 'ReactDOM',
          path: `umd/react-dom.production.min.js`,
        },
      ],
    }),
  ],
  build: {
    target: 'es2018',
    format: 'esm',
    minify: false,
    outDir: '../priv/static',
    emptyOutDir: true,
    assetsInlineLimit: 0,
    rollupOptions: {
      external: ['react', 'react-dom'],
      input: ['app.tsx'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
        },
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
