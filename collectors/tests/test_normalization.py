from pruevia_collectors.normalization import CatalogResolver, CatalogTerm, normalize_text


def test_normalize_text_matches_database_contract():
    assert normalize_text("  Electromiografía + VCN / Nervios  ") == "electromiografia vcn nervios"


def test_exact_and_global_alias_resolve_automatically():
    resolver = CatalogResolver()
    terms = [CatalogTerm("item-emg", "Electromiografía", aliases=("EMG",))]

    exact = resolver.resolve("Electromiografía", terms)
    alias = resolver.resolve("emg", terms)

    assert exact.status == "resolved"
    assert exact.selected_item_id == "item-emg"
    assert exact.candidates[0].method == "exact"
    assert alias.status == "resolved"
    assert alias.selected_item_id == "item-emg"
    assert alias.candidates[0].method == "alias"


def test_provider_alias_is_scoped_to_matching_brand():
    resolver = CatalogResolver()
    terms = [CatalogTerm("item-1", "Perfil tiroideo", provider_aliases=(("brand-chopo", "Perfil tiroides"),))]

    allowed = resolver.resolve("Perfil tiroides", terms, provider_brand_id="brand-chopo")
    other_brand = resolver.resolve("Perfil tiroides", terms, provider_brand_id="brand-other")

    assert allowed.status == "resolved"
    assert allowed.candidates[0].method == "provider_alias"
    assert other_brand.status == "ambiguous"
    assert other_brand.selected_item_id is None


def test_fuzzy_candidate_requires_review_and_does_not_auto_map():
    resolver = CatalogResolver()
    terms = [CatalogTerm("item-emg", "Electromiografía", aliases=("EMG",))]

    decision = resolver.resolve("Electromiografia de miembros", terms)

    assert decision.status == "ambiguous"
    assert decision.selected_item_id is None
    assert decision.candidates[0].method == "trigram"


def test_distinct_service_with_extra_clinical_detail_is_not_collapsed_to_emg():
    resolver = CatalogResolver()
    terms = [CatalogTerm("item-emg", "Electromiografía", aliases=("EMG",))]

    decision = resolver.resolve("EMG + velocidades de conducción", terms)

    assert decision.status in {"ambiguous", "no_match"}
    assert decision.selected_item_id is None


def test_fuzzy_match_requires_a_meaningful_token_overlap():
    terms = [CatalogTerm("item-emg", "Electromiografia", aliases=("EMG",))]

    decision = CatalogResolver().resolve("codigo postal", terms)

    assert decision.status == "no_match"
    assert decision.candidates == ()


def test_empty_input_has_no_match():
    assert CatalogResolver().resolve("   ", [CatalogTerm("item", "Biometría hemática")]).status == "no_match"
