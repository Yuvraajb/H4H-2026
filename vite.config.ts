import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { webspatial } from '@webspatial/vite-plugin';
import { createHtmlPlugin } from 'vite-plugin-html';

export default defineConfig({
  plugins: [
    react(),
    webspatial(),
    createHtmlPlugin({
      inject: {
        data: {
          XR_ENV: process.env.XR_ENV || 'web',
        },
      },
    }),
  ],
  server: {
    port: 5175,
    host: true,
  },
});
