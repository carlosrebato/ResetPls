import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';
export default defineConfig({ build: { rollupOptions: { input: { main: fileURLToPath(new URL('./index.html', import.meta.url)), en: fileURLToPath(new URL('./en/index.html', import.meta.url)), es: fileURLToPath(new URL('./es/index.html', import.meta.url)), privacy: fileURLToPath(new URL('./privacy/index.html', import.meta.url)), privacyEs: fileURLToPath(new URL('./es/privacy/index.html', import.meta.url)) } } } });
