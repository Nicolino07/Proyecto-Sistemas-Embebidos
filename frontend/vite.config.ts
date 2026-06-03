import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/admin': 'http://localhost:8001',
      '/accesos': 'http://localhost:8001',
      '/usuarios': 'http://localhost:8001',
      '/zonas': 'http://localhost:8001',
      '/puntos': 'http://localhost:8001',
      '/nodos': 'http://localhost:8001',
      '/reconocer': 'http://localhost:8001',
      '/registrar': 'http://localhost:8001',
    },
  },
})
