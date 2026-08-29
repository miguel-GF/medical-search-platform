FROM python:3.10-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src ./src

RUN python -m pip install --no-cache-dir .

ENV OCR_HOST=0.0.0.0
ENV OCR_PORT=8000

EXPOSE 8000

CMD ["uvicorn", "pruevia_ocr_service.app:app", "--host", "0.0.0.0", "--port", "8000"]
