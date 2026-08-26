import { createWorkerHandler } from './app.js';
import type { Env } from './types.js';

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return createWorkerHandler(env)(request, env);
  },
};
