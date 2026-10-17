const allowedOrigins = new Set([
  'https://pruevia.com.mx',
  'https://app.pruevia.com.mx',
  'https://admin.pruevia.com.mx',
]);

export default {
  async fetch(request: Request): Promise<Response> {
    const headers = new Headers({
      'Cache-Control': 'no-store, max-age=0',
      'Content-Type': 'application/json; charset=utf-8',
      'Retry-After': '86400',
    });
    const origin = request.headers.get('Origin');
    if (origin && allowedOrigins.has(origin)) {
      headers.set('Access-Control-Allow-Origin', origin);
      headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Client-Info, Apikey');
      headers.set('Vary', 'Origin');
    }

    return new Response(JSON.stringify({
      status: 'temporarily_unavailable',
      message: 'Pruevia está temporalmente en pausa. Visita pruevia.com.mx para más información.',
    }), { status: 503, headers });
  },
};
