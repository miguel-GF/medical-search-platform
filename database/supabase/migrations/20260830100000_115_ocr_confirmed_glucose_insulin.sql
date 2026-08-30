-- Human-confirmed transcription from the second prescription sample.
--
-- This is deliberately an auditable OCR suggestion only. The phrase contains
-- two studies and the generic Insulina concept is not yet a canonical catalog
-- item, so this rule must not create a false equivalence or publish offers.

begin;

insert into catalog.ocr_correction_rules(
  locale, normalized_input, suggested_text, normalized_suggestion,
  correction_type, confidence, status, source_note, approved_at
)
values (
  'es-MX',
  'gluroso e inuliua',
  'Glucosa e Insulina',
  'glucosa e insulina',
  'lexical_review',
  0.9000,
  'approved',
  'Human-confirmed transcription from the Puebla prescription sample. The line contains two studies; generic Insulina remains a catalog-gap requiring clinical definition and confirmation.',
  now()
)
on conflict (locale, normalized_input) do update
set suggested_text = excluded.suggested_text,
    normalized_suggestion = excluded.normalized_suggestion,
    correction_type = excluded.correction_type,
    confidence = excluded.confidence,
    status = excluded.status,
    source_note = excluded.source_note,
    approved_at = excluded.approved_at;

commit;
