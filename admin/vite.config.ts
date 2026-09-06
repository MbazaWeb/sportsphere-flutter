import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: '/admin/',
  plugins: [react()],
  server: { port: 5173, host: true, proxy: { '/v1': 'https://playifysport.fun', '/health': 'https://playifysport.fun' } },
})
