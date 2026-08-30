from pruevia_ocr_service.engine import RecognizedLine, format_order_lines


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

    assert [line.text for line in result] == ["GlurOsO e INUliUA"]
    assert result[0].confidence == 0.62


def test_format_order_lines_keeps_raw_uncertain_study_text():
    result = format_order_lines([RecognizedLine("Pertil firondle", 0.84)])

    assert result[0].text == "Pertil firondle"
