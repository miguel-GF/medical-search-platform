# The ClamAV daemon is a separate private sidecar. Never expose its TCP port.
# Pin the multi-architecture manifest by digest; update only through a
# reviewed base-image refresh.
FROM python:3.10-slim-bookworm@sha256:68d914ec641a0b69267ce65184d000a2bc3a9ee2590ab702b82250ab2385735a

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app

COPY pyproject.toml constraints.txt ./
COPY src ./src

RUN python -m pip install --constraint constraints.txt . \
    && addgroup --system pruevia-scanner \
    && adduser --system --ingroup pruevia-scanner --no-create-home pruevia-scanner \
    && mkdir -p /run/clamav \
    && chown root:pruevia-scanner /run/clamav \
    && chmod 0750 /run/clamav

USER pruevia-scanner

ENTRYPOINT ["pruevia-document-scanner"]
