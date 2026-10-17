export default {
  fetch() {
    return new Response(null, {
      status: 302,
      headers: {
        Location: 'https://pruevia.com.mx/',
        'Cache-Control': 'no-store, max-age=0',
      },
    });
  },
};
