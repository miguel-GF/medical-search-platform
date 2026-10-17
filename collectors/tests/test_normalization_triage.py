import json
import sys

from pruevia_collectors.cli_normalization_triage import main
from pruevia_collectors.normalization_triage import triage


def _group(label: str, **overrides):
    group = {
        'normalized_input': label,
        'provider_brand_id': 'brand-a',
        'provider_sku': 'sku-1',
        'distinct_sku_count': 1,
        'occurrence_count': 7,
        'source_type': 'provider_official',
        'source_usage_policy_status': 'approved',
        'source_url': 'https://provider.example/estudio',
    }
    group.update(overrides)
    return group


def _term(item_id: str, name: str, *, provider=None, kind='name'):
    return {
        'item_id': item_id, 'display_name': name, 'term': name,
        'term_type': kind, 'provider_brand_id': provider,
    }


def test_exact_approved_alias_is_only_a_reprocess_preview():
    result = triage([_group('bh')], [_term('item-1', 'BH', provider='brand-a', kind='alias')])
    assert result['groups'][0]['outcome'] == 'approved_term_reprocess_preview'
    assert result['groups'][0]['review_action'] == 'preview_exact_reprocess'
    assert result['groups'][0]['unique_exact_candidate'] is True
    assert len(result['groups'][0]['review_cluster_key']) == 20
    assert result['mode'] == 'read_only_suggestions'


def test_exact_collision_never_selects_an_arbitrary_item():
    result = triage([_group('bh')], [
        _term('item-1', 'BH', provider='brand-a', kind='alias'),
        _term('item-2', 'BH', provider='brand-a', kind='alias'),
    ])
    assert result['groups'][0]['outcome'] == 'exact_collision_review'
    assert result['groups'][0]['review_action'] == 'review_exact_collision'
    assert result['groups'][0]['unique_exact_candidate'] is False
    assert len(result['groups'][0]['suggestions']) == 2


def test_new_label_generates_review_cluster_without_creating_a_draft():
    result = triage([_group('panel nuevo')], [])
    entry = result['groups'][0]
    assert entry['outcome'] == 'catalog_gap'
    assert len(entry['review_cluster_key']) == 20
    assert 'draft_key' not in entry
    assert entry['source_identifier_count'] == 1
    assert result['represented_rows'] == 7


def test_review_cluster_does_not_mistake_distinct_source_ids_for_concepts():
    first = triage([_group('panel nuevo', provider_sku='branch-1', distinct_sku_count=7)], [])['groups'][0]
    second = triage([_group('panel nuevo', provider_sku='branch-2', distinct_sku_count=7)], [])['groups'][0]
    assert first['review_cluster_key'] == second['review_cluster_key']
    assert first['source_identifier_count'] == 7
    assert second['source_identifier_count'] == 7
    assert first['representative_source_identifier'] != second['representative_source_identifier']


def test_weak_fuzzy_overlap_does_not_make_a_catalog_gap_look_covered():
    result = triage([_group('panel de cabello especializado')], [_term('item-1', 'Panel de lípidos')])
    assert result['groups'][0]['outcome'] == 'catalog_gap'
    assert result['groups'][0]['suggestions'] == []


def test_unreviewed_source_and_multiple_identifiers_remain_separate_signals():
    result = triage([_group(
        'panel nuevo', source_usage_policy_status='review_required',
        distinct_sku_count=2,
    )], [])
    entry = result['groups'][0]
    assert 'source_policy_not_approved' in entry['holds']
    assert entry['source_identifier_count'] == 2
    assert 'provider_sku_not_unique' not in entry['holds']
    assert entry['review_action'] == 'review_source_policy'


def test_public_website_with_https_is_not_provider_official_evidence():
    result = triage([_group('panel nuevo', source_type='public_website')], [])
    holds = result['groups'][0]['holds']
    assert 'provider_official_source_unverified' in holds
    assert 'https_source_missing' not in holds
    assert result['groups'][0]['review_cluster_key']


def test_official_source_without_https_has_separate_hold():
    result = triage([_group('panel nuevo', source_url='http://provider.example/estudio')], [])
    holds = result['groups'][0]['holds']
    assert 'https_source_missing' in holds
    assert 'provider_official_source_unverified' not in holds


def test_report_removes_source_url_query_and_fragment():
    result = triage([_group('panel nuevo', source_url='https://provider.example/path?token=private#section')], [])
    assert result['groups'][0]['source_url'] == 'https://provider.example/path'
    assert 'private' not in json.dumps(result)


def test_fuzzy_match_is_only_a_suggestion():
    result = triage([_group('biometria hematica completa')], [_term('item-1', 'Biometría hemática')])
    assert result['groups'][0]['outcome'] == 'catalog_gap_with_suggestions'
    assert result['groups'][0]['suggestions'][0]['method'] == 'trigram'
    assert 'draft_key' not in result['groups'][0]


def test_generated_initialism_is_reported_as_a_review_suggestion():
    result = triage(
        [_group('bh')],
        [_term('item-1', 'Biometría hemática')],
    )
    entry = result['groups'][0]
    assert entry['outcome'] == 'catalog_gap_with_suggestions'
    assert entry['suggestions'] == [{
        'item_id': 'item-1',
        'name': 'Biometría hemática',
        'matched_term': 'Biometría hemática',
        'score': 0.95,
        'method': 'rules',
        'lexical_coverage': None,
        'unmatched_input_tokens': [],
        'core_lexical_coverage': None,
        'unmatched_core_terms': [],
        'clinical_modifier_conflicts': [],
        'specificity_not_preserved': [],
        'matched_term_specificity_not_preserved': [],
    }]


def test_fuzzy_candidate_shows_lexical_evidence_without_calling_it_clinical_confidence():
    entry = triage(
        [_group('biometria hematica completa')],
        [_term('item-1', 'Biometría hemática')],
    )['groups'][0]
    suggestion = entry['suggestions'][0]
    assert entry['review_action'] == 'review_clinical_equivalence'
    assert suggestion['matched_term'] == 'Biometría hemática'
    assert suggestion['lexical_coverage'] == 0.667
    assert suggestion['unmatched_input_tokens'] == ['completa']
    assert suggestion['clinical_modifier_conflicts'] == []


def test_conflicting_imaging_direction_is_explicitly_flagged():
    entry = triage(
        [_group('ultrasonido abdominal inferior')],
        [_term('item-1', 'Ultrasonido abdominal superior')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['review_action'] == 'catalog_gap_after_rejecting_unsafe_candidates'
    assert entry['rejected_candidates'][0]['clinical_modifier_conflicts'] == ['direction:inferior!=superior']


def test_conflicting_specimen_is_explicitly_flagged():
    entry = triage(
        [_group('creatinina en orina')],
        [_term('item-1', 'Creatinina en suero')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['rejected_candidates'][0]['clinical_modifier_conflicts'] == ['specimen:urine!=serum']


def test_candidate_with_shared_specimen_but_wrong_analyte_is_rejected():
    entry = triage(
        [_group('cobre en suero')],
        [_term('item-1', 'T4 libre en suero')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['rejected_candidates'][0]['rejection_reason'] == 'no_shared_core_terms'
    assert entry['rejected_candidates'][0]['unmatched_core_terms'] == ['cobre']


def test_conflicting_imaging_modalities_are_explicitly_flagged():
    entry = triage(
        [_group('rm columna cervical simple')],
        [_term('item-1', 'TAC columna cervical simple')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['rejected_candidates'][0]['clinical_modifier_conflicts'] == ['modality:mri!=ct']


def test_missing_specific_imaging_route_is_not_hidden():
    entry = triage(
        [_group('ultrasonido obstetrico transvaginal')],
        [_term('item-1', 'Ultrasonido obstétrico')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['rejected_candidates'][0]['specificity_not_preserved'] == ['route:transvaginal']


def test_exact_candidate_is_not_actionable_while_source_policy_is_unreviewed():
    entry = triage(
        [_group('biometria hematica', source_usage_policy_status='review_required')],
        [_term('item-1', 'Biometría hemática')],
    )['groups'][0]
    assert entry['outcome'] == 'approved_term_reprocess_preview'
    assert entry['unique_exact_candidate'] is True
    assert entry['review_action'] == 'review_source_policy'


def test_article_only_difference_is_a_separate_deterministic_preview():
    entry = triage(
        [_group('hormona estimulante de la tiroides')],
        [_term('item-1', 'Hormona estimulante de tiroides')],
    )['groups'][0]
    assert entry['outcome'] == 'deterministic_article_fold_preview'
    assert entry['exact_candidate_methods'] == ['article_fold']
    assert entry['review_action'] == 'preview_deterministic_article_fold'


def test_article_fold_collision_does_not_choose_a_catalog_item():
    entry = triage(
        [_group('hormona de tiroides')],
        [
            _term('item-1', 'Hormona la de tiroides'),
            _term('item-2', 'Hormona de la tiroides'),
        ],
    )['groups'][0]
    assert entry['outcome'] == 'exact_collision_review'
    assert entry['unique_exact_candidate'] is False


def test_article_fold_keeps_negation_and_prepositions_significant():
    entry = triage(
        [_group('ultrasonido sin contraste')],
        [_term('item-1', 'Ultrasonido con contraste')],
    )['groups'][0]
    assert entry['outcome'] != 'deterministic_article_fold_preview'


def test_tc_and_mri_are_explicitly_different_modalities():
    entry = triage(
        [_group('tc de columna cervical')],
        [_term('item-1', 'RM de columna cervical')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert 'modality:ct!=mri' in entry['rejected_candidates'][0]['clinical_modifier_conflicts']


def test_distinct_anatomical_sites_are_rejected_but_de_pie_is_not_foot_site():
    false_site = triage(
        [_group('resonancia magnética de mano simple')],
        [_term('item-1', 'Resonancia magnética de mama simple')],
    )['groups'][0]
    assert false_site['suggestions'] == []
    assert 'anatomy:hand!=breast' in false_site['rejected_candidates'][0]['clinical_modifier_conflicts']

    standing = triage(
        [_group('abdomen de pie')],
        [_term('item-1', 'Radiografía de abdomen de pie')],
    )['groups'][0]
    assert not any(
        conflict.startswith('anatomy:')
        for suggestion in standing['suggestions']
        for conflict in suggestion['clinical_modifier_conflicts']
    )


def test_pregnancy_trimester_mismatch_is_not_a_plausible_equivalence():
    entry = triage(
        [_group('ultrasonido obstétrico trim ii')],
        [_term('item-1', 'Ultrasonido obstétrico trim i')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert 'trimester:2!=1' in entry['rejected_candidates'][0]['clinical_modifier_conflicts']


def test_missing_pregnancy_trimester_is_reported_as_lost_specificity():
    entry = triage(
        [_group('ultrasonido obstétrico trim ii y iii')],
        [_term('item-1', 'Ultrasonido obstétrico')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert entry['rejected_candidates'][0]['specificity_not_preserved'] == [
        'trimester:2', 'trimester:3'
    ]


def test_incomplete_projection_and_panel_scope_are_not_plausible_matches():
    projections = triage(
        [_group('panoramica de columna total lateral')],
        [_term('item-1', 'Panoramica de columna ap')],
    )['groups'][0]
    assert projections['suggestions'] == []
    assert 'projection:lateral!=ap' in projections['rejected_candidates'][0]['clinical_modifier_conflicts']

    panel = triage(
        [_group('quimica sanguinea completa')],
        [_term('item-1', 'Química sanguínea básica')],
    )['groups'][0]
    assert panel['suggestions'] == []
    assert 'panel_scope:complete!=basic' in panel['rejected_candidates'][0]['clinical_modifier_conflicts']


def test_simple_and_contrast_both_requested_is_not_reduced_to_simple_only():
    entry = triage(
        [_group('tc de columna cervical simple y contrastada')],
        [_term('item-1', 'TAC de columna cervical simple')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert 'contrast:with' in entry['rejected_candidates'][0]['specificity_not_preserved']


def test_angiographic_protocol_is_not_collapsed_into_generic_ct():
    entry = triage(
        [_group('angiotomografia de abdomen contrastada')],
        [_term('item-1', 'Tomografía de abdomen completo con contraste')],
    )['groups'][0]
    assert entry['suggestions'] == []
    assert 'protocol:angiographic' in entry['rejected_candidates'][0]['specificity_not_preserved']


def test_cli_fixture_mode_writes_only_a_read_only_report(tmp_path, monkeypatch):
    groups = tmp_path / 'groups.json'
    terms = tmp_path / 'terms.json'
    report = tmp_path / 'report.json'
    groups.write_text(json.dumps([_group('panel nuevo')]), encoding='utf-8')
    terms.write_text('[]', encoding='utf-8')
    monkeypatch.setattr(sys, 'argv', [
        'pruevia-normalization-triage', '--groups-fixture', str(groups),
        '--terms-fixture', str(terms), '--output', str(report),
    ])
    main()
    payload = json.loads(report.read_text(encoding='utf-8'))
    assert payload['mode'] == 'read_only_suggestions'
    assert payload['outcomes'] == {'catalog_gap': 1}
