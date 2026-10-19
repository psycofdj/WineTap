import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { apiSimulee } from './mock/serveur.js';

// Le site est servi par le téléphone, sans Internet : tout est empaqueté (polices comprises).
export default defineConfig(({ command }) => ({
  plugins: [svelte(), command === 'serve' ? apiSimulee() : null],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // WebView Android récente et Safari d'iOS 15 au moins
    target: ['es2020', 'safari15', 'chrome100'],
    assetsInlineLimit: 0,
  },
  server: {
    host: true,
    port: 5173,
  },
}));
