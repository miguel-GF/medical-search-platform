-- Token-level variants produced after splitting the confirmed compound row.
-- These rules correct OCR spelling only; Insulina remains a catalog review gap.

begin;

insert into catalog.ocr_correction_rules(
  locale, normalized_input, suggested_text, normalized_suggestion,
  correction_type, confidence, status, source_note, approved_at
)
values
  (
    'es-MX', 'gluroso', 'Glucosa', 'glucosa', 'lexical_review', 0.9000, 'approved',
    'Token extracted from the human-confirmed compound prescription row; OCR correction only.', now()
  ),
  (
    'es-MX', 'inuliua', 'Insulina', 'insulina', 'lexical_review', 0.9000, 'approved',
    'Token extracted from the human-confirmed compound prescription row; generic Insulina still requires catalog definition.', now()
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
