# Pin the multi-architecture manifest by digest; tags are mutable and must not
# silently change the runtime or its system libraries between builds.
FROM python:3.10-slim@sha256:fd76ade0c607f27677bc04be3c60749f400eedc941d9e72967e19a4cedff80c2

WORKDIR /app

COPY pyproject.toml constraints.txt README.md ./
COPY src ./src

RUN python -m pip install --no-cache-dir --constraint constraints.txt . \
    && python -m rapidocr.main download_models \
    && MODEL_DIR="$(python -c 'import rapidocr; from pathlib import Path; print(Path(rapidocr.__file__).parent / "models")')" \
    && printf '%s  %s\n' \
      '090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f' "$MODEL_DIR/PP-OCRv6_det_small.onnx" \
      '6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884' "$MODEL_DIR/PP-OCRv6_rec_small.onnx" \
      'e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c' "$MODEL_DIR/ch_ppocr_mobile_v2.0_cls_mobile.onnx" \
      | sha256sum -c - \
    && mkdir -p /opt/pruevia/models \
    && cp -a "$MODEL_DIR/." /opt/pruevia/models/ \
    && chmod -R a=rX /opt/pruevia/models

RUN addgroup --system pruevia && adduser --system --ingroup pruevia --no-create-home pruevia

ENV OCR_HOST=0.0.0.0
ENV OCR_PORT=8000
ENV OCR_MODEL_ROOT=/opt/pruevia/models

EXPOSE 8000

USER pruevia

CMD ["uvicorn", "pruevia_ocr_service.app:app", "--host", "0.0.0.0", "--port", "8000"]
