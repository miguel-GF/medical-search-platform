import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { publicApiUrl } from '../shared/site.mjs';

const output = resolve('.output/public/_headers');
const apiUrl = publicApiUrl(process.env.NUXT_PUBLIC_API_URL);
const apiOrigin = apiUrl ? new URL(apiUrl).origin : '';
const source = await readFile(output, 'utf8');
const rendered = source.replace(
  /connect-src 'self'(?: [^;]+)?;/,
  `connect-src 'self'${apiOrigin ? ` ${apiOrigin}` : ''};`,
);
if (rendered === source && apiOrigin) throw new Error('Landing CSP template is missing connect-src');
await writeFile(output, rendered, 'utf8');
