export default defineEventHandler((event) => {
  const config = useRuntimeConfig();
  const publication = config.public.publication;
  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8');
  return publication.indexable
    ? `User-agent: *\nAllow: /\nSitemap: ${publication.siteUrl}/sitemap.xml\n`
    : 'User-agent: *\nDisallow: /\n';
});
