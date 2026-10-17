export default defineEventHandler((event) => {
  const config = useRuntimeConfig();
  const publication = config.public.publication;
  if (!publication.indexable || !publication.siteUrl) throw createError({ statusCode: 404 });
  setHeader(event, 'Content-Type', 'application/xml; charset=utf-8');
  const origin = String(publication.siteUrl).replace(/&/g, '&amp;').replace(/</g, '&lt;');
  return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${origin}/</loc></url><url><loc>${origin}/prueba-android</loc></url><url><loc>${origin}/privacidad</loc></url></urlset>`;
});
