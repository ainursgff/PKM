import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],

  server: {
    port: 5173,

    /**
     * Proxy — semua request /api/* dan /makanan/* di-forward ke backend.
     * Ini menyelesaikan masalah CORS di development.
     *
     * Browser request:  http://localhost:5173/api/makanan
     * Vite forward ke:  http://192.168.1.2:3000/api/makanan
     */
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
      '/makanan': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
