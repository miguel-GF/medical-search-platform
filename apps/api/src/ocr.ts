import { PACKAGE_MAX_TEXT_LENGTH } from './batch.js';
import type { OcrAiBinding } from './types.js';

export const OCR_MAX_BYTES = 5 * 1024 * 1024;
export const OCR_MAX_BASE64_LENGTH = Math.ceil(OCR_MAX_BYTES / 3) * 4 + 64;
export const OCR_MAX_OUTPUT_TOKENS = 384;
export const DEFAULT_OCR_MODEL = '@cf/moondream/moondream3.1-9B-A2B';
export const OCR_PROMPT = [
  'Act as a literal OCR transcriber for this medical order.',
  'The photo may be rotated, skewed, low contrast, or handwritten; read it in any orientation.',
  'Return only the visible study/order text, one item per line, in reading order.',
  'Preserve abbreviations, punctuation, accents and spelling exactly as visible.',
  'Do not expand abbreviations, correct spelling, infer missing words, or describe the image.',
  'Omit patient name, date, physician credentials, signatures, contact details and decoration.',
  'If a character is unreadable, write [?] instead of guessing.',
].join(' ');

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

export interface OcrImageInput {
  bytes: number[];
  mime_type: string;
}

export interface OcrResult {
  text: string;
  model: string;
  input_bytes: number;
}

export class OcrInputError extends Error {
  readonly code = 'invalid_image';
}

export class OcrUnavailableError extends Error {
  readonly code = 'ocr_unavailable';
}

export class OcrRecognitionError extends Error {
  readonly code = 'ocr_failed';
}

export function parseOcrImageInput(input: Record<string, unknown>): OcrImageInput {
  if (typeof input.image !== 'string' || input.image.trim() === '') {
    throw new OcrInputError('image is required as base64 or a data URL');
  }
  let encoded = input.image.trim();
  let mimeType = typeof input.mime_type === 'string' ? input.mime_type.trim().toLowerCase() : '';
  const dataUrl = encoded.match(/^data:(image\/(?:jpeg|png|webp));base64,([a-z0-9+/=\s]+)$/i);
  if (dataUrl) {
    mimeType = dataUrl[1].toLowerCase();
    encoded = dataUrl[2];
  }
  if (!ALLOWED_MIME_TYPES.has(mimeType)) {
    throw new OcrInputError('mime_type must be image/jpeg, image/png or image/webp');
  }
  encoded = encoded.replace(/\s/g, '');
  if (!encoded || encoded.length > OCR_MAX_BASE64_LENGTH || !/^[a-z0-9+/]+={0,2}$/i.test(encoded) || encoded.length % 4 === 1) {
    throw new OcrInputError('image base64 is invalid or exceeds the 5 MiB limit');
  }
  let binary: string;
  try {
    binary = atob(encoded);
  } catch {
    throw new OcrInputError('image base64 is invalid');
  }
  if (binary.length === 0 || binary.length > OCR_MAX_BYTES) {
    throw new OcrInputError('image must be between 1 byte and 5 MiB');
  }
  const bytes = new Array<number>(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  if (!hasImageSignature(bytes, mimeType)) {
    throw new OcrInputError('image bytes do not match the declared MIME type');
  }
  return { bytes, mime_type: mimeType };
}

export async function recognizeOrderImage(
  ai: OcrAiBinding | undefined,
  input: OcrImageInput,
  model = DEFAULT_OCR_MODEL,
): Promise<OcrResult> {
  if (!ai) throw new OcrUnavailableError('OCR AI binding is not configured');
  let output: unknown;
  try {
    output = await ai.run(model, buildOcrModelInput(input, model));
  } catch (error) {
    throw new OcrRecognitionError(error instanceof Error ? error.message : 'OCR model failed');
  }
  const text = cleanOcrText(output);
  if (!text) throw new OcrRecognitionError('OCR model returned no readable text');
  return { text, model, input_bytes: input.bytes.length };
}

function cleanOcrText(output: unknown): string {
  const raw = output && typeof output === 'object'
    ? (output as { answer?: unknown; description?: unknown; response?: unknown }).answer
      ?? (output as { description?: unknown }).description
      ?? (output as { response?: unknown }).response
    : typeof output === 'string' ? output : null;
  if (typeof raw !== 'string') return '';
  return raw
    .replace(/^```(?:text|plain)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .replace(/^\s*(?:ocr|transcription|transcripci[oó]n)\s*:\s*/i, '')
    .replace(/\r\n?/g, '\n')
    .trim()
    .slice(0, PACKAGE_MAX_TEXT_LENGTH);
}

function buildOcrModelInput(input: OcrImageInput, model: string): Record<string, unknown> {
  if (model.toLowerCase().startsWith('@cf/moondream/')) {
    return {
      task: 'query',
      image: `data:${input.mime_type};base64,${bytesToBase64(input.bytes)}`,
      question: OCR_PROMPT,
      reasoning: false,
      max_tokens: OCR_MAX_OUTPUT_TOKENS,
      temperature: 0,
      stream: false,
    };
  }
  return {
    image: input.bytes,
    prompt: OCR_PROMPT,
    max_tokens: OCR_MAX_OUTPUT_TOKENS,
    temperature: 0,
    seed: 13,
  };
}

function bytesToBase64(bytes: number[]): string {
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += 32_768) {
    binary += String.fromCharCode(...bytes.slice(offset, offset + 32_768));
  }
  return btoa(binary);
}

function hasImageSignature(bytes: number[], mimeType: string): boolean {
  if (mimeType === 'image/jpeg') {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (mimeType === 'image/png') {
    return bytes.length >= 8
      && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47
      && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
  }
  return bytes.length >= 12
    && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46
    && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50;
}
