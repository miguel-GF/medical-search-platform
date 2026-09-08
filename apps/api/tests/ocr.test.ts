import { describe, expect, it } from 'vitest';
import {
  OcrInputError,
  OcrRecognitionError,
  OcrUnavailableError,
  OCR_PROMPT,
  parseOcrImageInput,
  recognizeOrderImage,
  recognizeOrderImageViaService,
} from '../src/ocr.js';
import type { OcrAiBinding } from '../src/types.js';

describe('OCR input boundary', () => {
  it('accepts a supported data URL and decodes bytes without storing the image', () => {
    const result = parseOcrImageInput({ image: 'data:image/jpeg;base64,/9j/4AA=', mime_type: 'image/png' });
    expect(result.mime_type).toBe('image/jpeg');
    expect(result.bytes).toEqual([255, 216, 255, 224, 0]);
  });

  it('rejects unsupported, malformed and empty images', () => {
    expect(() => parseOcrImageInput({ image: 'AAE=', mime_type: 'application/pdf' })).toThrowError(OcrInputError);
    expect(() => parseOcrImageInput({ image: 'not base64', mime_type: 'image/jpeg' })).toThrowError(OcrInputError);
    expect(() => parseOcrImageInput({ image: '', mime_type: 'image/jpeg' })).toThrowError(OcrInputError);
    expect(() => parseOcrImageInput({ image: 'AAE=', mime_type: 'image/jpeg' })).toThrowError(OcrInputError);
  });

  it('rejects an OCR service URL with a path before sending the image or token', async () => {
    await expect(recognizeOrderImageViaService(
      'https://ocr.example/internal',
      'x'.repeat(32),
      { bytes: [255, 216, 255], mime_type: 'image/jpeg' },
      1_000,
      false,
    )).rejects.toBeInstanceOf(OcrUnavailableError);
  });

  it('rejects private and loopback OCR hosts outside local development', async () => {
    for (const url of ['https://127.0.0.1', 'https://10.0.0.7', 'https://[::1]']) {
      await expect(recognizeOrderImageViaService(
        url,
        'x'.repeat(32),
        { bytes: [255, 216, 255], mime_type: 'image/jpeg' },
        1_000,
        false,
      )).rejects.toBeInstanceOf(OcrUnavailableError);
    }
  });
});

describe('literal order transcription', () => {
  it('calls the AI extractor with a no-inference prompt and cleans its text output', async () => {
    let received: Record<string, unknown> | undefined;
    const ai: OcrAiBinding = {
      run: async (_model, inputs) => {
        received = inputs;
        return { answer: '```text\n1. B.H.\n2. EGO\n```' };
      },
    };
    const result = await recognizeOrderImage(ai, { bytes: [255, 216, 255, 224, 0, 0], mime_type: 'image/jpeg' });
    expect(result.text).toBe('1. B.H.\n2. EGO');
    expect(received?.question).toBe(OCR_PROMPT);
    expect(received?.temperature).toBe(0);
    expect(received?.task).toBe('query');
    expect(received?.image).toBe('data:image/jpeg;base64,/9j/4AAA');
    expect(received?.reasoning).toBe(false);
  });

  it('fails closed when no binding or no readable text is available', async () => {
    await expect(recognizeOrderImage(undefined, { bytes: [0], mime_type: 'image/jpeg' })).rejects.toBeInstanceOf(OcrUnavailableError);
    const ai: OcrAiBinding = { run: async () => ({ answer: '   ' }) };
    await expect(recognizeOrderImage(ai, { bytes: [0], mime_type: 'image/jpeg' })).rejects.toBeInstanceOf(OcrRecognitionError);
  });

  it('keeps the legacy LLaVA adapter available when explicitly configured', async () => {
    let received: Record<string, unknown> | undefined;
    const ai: OcrAiBinding = {
      run: async (_model, inputs) => {
        received = inputs;
        return { description: 'EGO' };
      },
    };
    const result = await recognizeOrderImage(
      ai,
      { bytes: [255, 216, 255], mime_type: 'image/jpeg' },
      '@cf/llava-hf/llava-1.5-7b-hf',
    );
    expect(result.text).toBe('EGO');
    expect(received?.image).toEqual([255, 216, 255]);
    expect(received?.prompt).toBe(OCR_PROMPT);
  });
});
