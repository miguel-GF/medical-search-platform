import { defineConfig, loadEnv, type Plugin } from 'vite';
import vue from '@vitejs/plugin-vue';

function securityPolicy(mode: string): Plugin {
  return {
    name: 'pruevia-security-policy',
    transformIndexHtml(html, context) {
      const env = loadEnv(mode, context.server?.config.root ?? process.cwd(), 'VITE_');
      const allowedApiHosts = (env.VITE_API_ALLOWED_HOSTS ?? '')
        .split(',')
        .map((host) => host.trim().toLowerCase())
        .filter(Boolean);
      const allowedSupabaseHosts = (env.VITE_SUPABASE_ALLOWED_HOSTS ?? '')
        .split(',')
        .map((host) => host.trim().toLowerCase())
        .filter(Boolean);
      if (mode === 'production') {
        if (!env.VITE_SUPABASE_URL?.trim() || allowedSupabaseHosts.length === 0) {
          throw new Error('VITE_SUPABASE_URL and VITE_SUPABASE_ALLOWED_HOSTS are required for production builds');
        }
        if (allowedSupabaseHosts.some((host) => !/^[a-z0-9.-]+$/.test(host) || host.includes('..'))) {
          throw new Error('VITE_SUPABASE_ALLOWED_HOSTS must contain exact DNS hostnames');
        }
      }
      if (mode === 'production' && env.VITE_API_URL?.trim()) {
        if (allowedApiHosts.length === 0) throw new Error('VITE_API_ALLOWED_HOSTS is required for production builds');
        if (allowedApiHosts.some((host) => !/^[a-z0-9.-]+$/.test(host) || host.includes('..'))) {
          throw new Error('VITE_API_ALLOWED_HOSTS must contain exact DNS hostnames');
        }
      }
      const sources = new Set<string>();
      for (const name of ['VITE_API_URL', 'VITE_SUPABASE_URL']) {
        const raw = env[name]?.trim();
        if (!raw) continue;
        let parsed: URL;
        try {
          parsed = new URL(raw);
        } catch {
          throw new Error(`${name} must be an absolute URL`);
        }
        const local = mode !== 'production'
          && parsed.protocol === 'http:'
          && ['localhost', '127.0.0.1', '::1'].includes(parsed.hostname);
        if (parsed.protocol !== 'https:' && !local) throw new Error(`${name} must use HTTPS`);
        if (parsed.username || parsed.password || parsed.search || parsed.hash
          || (parsed.protocol === 'https:' && parsed.port && parsed.port !== '443')
          || (parsed.pathname !== '' && parsed.pathname !== '/')) throw new Error(`${name} must be a clean origin without credentials, path, query or fragment`);
        if (mode === 'production' && name === 'VITE_API_URL'
          && !allowedApiHosts.includes(parsed.hostname.toLowerCase())) {
          throw new Error('VITE_API_URL hostname must be listed exactly in VITE_API_ALLOWED_HOSTS');
        }
        if (mode === 'production' && name === 'VITE_SUPABASE_URL'
          && !allowedSupabaseHosts.includes(parsed.hostname.toLowerCase())) {
          throw new Error('VITE_SUPABASE_URL hostname must be listed exactly in VITE_SUPABASE_ALLOWED_HOSTS');
        }
        sources.add(parsed.origin);
      }
      return html.replace('__PRUEVIA_CONNECT_SRC__', [...sources].join(' '));
    },
  };
}

export default defineConfig(({ mode }) => ({
  plugins: [securityPolicy(mode), vue()],
  test: { environment: 'node' },
}));
