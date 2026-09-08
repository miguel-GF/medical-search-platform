from pruevia_ocr_service.engine import RecognizedLine, format_order_lines


def test_rapidocr_fails_closed_when_verified_models_are_missing(tmp_path):
    from pruevia_ocr_service.engine import EngineUnavailableError, RapidOcrEngine

    try:
        RapidOcrEngine(model_root_dir=str(tmp_path))
    except EngineUnavailableError as exc:
        assert str(exc) == "verified RapidOCR models are not bundled"
    else:
        raise AssertionError("RapidOCR must not download models at request time")


def test_format_order_lines_extracts_study_after_fuzzy_laboratory_label():
    lines = [
        RecognizedLine(
            "LAOnATOnIO:①GlurOsO e INUliUA= Ginecología Obstetricia Ced. Prof. 4584311",
            0.62,
        ),
        RecognizedLine("Paciente: Lucy Aneli", 0.99),
        RecognizedLine("Privada de las Ramblas No. 4 Puebla", 0.99),
    ]

    result = format_order_lines(lines)

    assert [line.text for line in result] == ["GlurOsO", "INUliUA"]
    assert result[0].confidence == 0.62
    assert result[1].confidence == 0.62


def test_format_order_lines_keeps_raw_uncertain_study_text():
    result = format_order_lines([RecognizedLine("Pertil firondle", 0.84)])

    assert result[0].text == "Pertil firondle"


def test_format_order_lines_splits_explicit_study_conjunction():
    result = format_order_lines([RecognizedLine("Glucosa e Insulina", 0.80)])

    assert [line.text for line in result] == ["Glucosa", "Insulina"]


def test_format_order_lines_drops_english_report_metadata():
    result = format_order_lines([
        RecognizedLine("Patient Name: Doe, Jane Patient ID: JG05141985", 0.99),
        RecognizedLine("Imaging", 0.99),
        RecognizedLine("MRI Brain without contrast", 0.99),
        RecognizedLine("Findings: no acute abnormality", 0.99),
        RecognizedLine("Phone: (217) 555-1212", 0.99),
        RecognizedLine("weeks. Exam ID: IMG9876543", 0.99),
        RecognizedLine("hemorrhage, mass effect or midline shift", 0.99),
        RecognizedLine("City Health Clinic", 0.99),
        RecognizedLine("45 Oak Ave.", 0.99),
        RecognizedLine("Prescriked by: Dr. C. Rosse", 0.99),
        RecognizedLine("Parient: Aisha Khan, Agc: 73", 0.99),
        RecognizedLine("Signature:", 0.99),
        RecognizedLine("Way, Springfield, IL, 62704", 0.99),
    ])

    assert [line.text for line in result] == ["MRI Brain without contrast"]


def test_format_order_lines_trims_metadata_fused_after_imaging_study():
    result = format_order_lines([
        RecognizedLine("MRI Brain without contrast Springfield General Hospital Imaging Department 123 Health", 0.99),
        RecognizedLine("Way, Springfield, IL, 62704", 0.99),
    ])

    assert [line.text for line in result] == ["MRI Brain without contrast"]


def test_result_lines_bounds_adversarial_engine_output():
    from pruevia_ocr_service.engine import _result_lines

    class Result:
        txts = (f"Glucosa {index}" for index in range(10_000))
        scores = (0.9 for _ in range(10_000))
        boxes = None

    lines = _result_lines(Result(), 0.3)
    assert len(lines) == 500
    assert all(len(line.text) <= 500 for line in lines)


def test_format_order_lines_caps_conjunction_amplification():
    # One detector row can contain many conjunctions. The formatter must not
    # turn that into an unbounded response list.
    value = " e ".join(f"estudio{index}" for index in range(10_000))
    result = format_order_lines([RecognizedLine(value, 0.9)])
    assert len(result) == 500
