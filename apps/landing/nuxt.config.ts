import { publicationConfig } from './shared/site.mjs';

const publication = publicationConfig(process.env);

export default defineNuxtConfig({
  compatibilityDate: '2026-09-14',
  devtools: { enabled: false },
  css: ['~/assets/theme.css', '~/assets/main.css'],
  runtimeConfig: { public: publication },
  app: {
    head: {
      htmlAttrs: { lang: 'es-MX' },
      title: 'Pruevia — Tu próximo paso, más claro',
      meta: [
        { name: 'theme-color', content: '#0f766e' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    },
  },
  nitro: { prerender: { routes: ['/', '/privacidad', '/prueba-android', '/robots.txt', ...(publication.indexable ? ['/sitemap.xml'] : [])] } },
});
