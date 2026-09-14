export default defineEventHandler((event) => {
  const config = useRuntimeConfig();
  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8');
  return config.public.indexable
    ? `User-agent: *\nAllow: /\nSitemap: ${config.public.siteUrl}/sitemap.xml\n`
    : 'User-agent: *\nDisallow: /\n';
});
