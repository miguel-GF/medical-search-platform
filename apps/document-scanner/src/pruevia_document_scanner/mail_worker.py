"""Bounded SMTP outbox worker. No public endpoint; no message bodies in logs."""
import asyncio
import json
import os
import re
import smtplib
import ssl
from datetime import datetime, timezone
from email.message import EmailMessage
from urllib.parse import urlencode, urlsplit

import httpx
from .worker import Supabase


def clean_email(value: str) -> str:
    if not isinstance(value, str) or len(value) > 254 or not re.fullmatch(r"[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+", value):
        raise ValueError("invalid_mail_address")
    return value


def portal_url(value: str) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
            or parsed.port not in (None, 443) or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
        raise ValueError("invalid_portal_origin")
    return value.rstrip("/") + "/?provider=1"


def compose(job: dict, sender: str, portal: str) -> EmailMessage:
    message = EmailMessage()
    message["From"] = clean_email(sender)
    message["To"] = clean_email(job["recipient"])
    message["Message-ID"] = f"<{job['id']}@{sender.split('@')[1]}>"
    target = portal_url(portal)
    if job["kind"] == "verification":
        if datetime.fromisoformat(job["expires_at"]).astimezone(timezone.utc) <= datetime.now(timezone.utc):
            raise ValueError("verification_expired")
        if not re.fullmatch(r"[a-f0-9]{64}", job.get("verification_code") or ""):
            raise ValueError("invalid_verification_code")
        target += "#" + urlencode({"application": job["application_id"], "code": job["verification_code"]})
        message["Subject"] = "Comprueba tu correo de trabajo · Pruevia"
        text = "Confirma tu correo de trabajo desde tu cuenta de Pruevia. El enlace vence a los 30 minutos de su emisión y sólo se usa una vez."
    else:
        message["Subject"] = "Hay novedades en tu solicitud · Pruevia"
        text = "Tu solicitud tiene una actualización. Entra a tu cuenta para consultar el estado y los siguientes pasos."
    message.set_content(f"{text}\n\n{target}\n\nSi no solicitaste este acceso, ignora este mensaje. No envíes documentos por correo.")
    return message


def send(message: EmailMessage, config: dict) -> None:
    # Authenticated TLS only; SMTP debug logging would leak credentials/content.
    with smtplib.SMTP_SSL(config["SMTP_HOST"], int(config.get("SMTP_PORT", "465")), timeout=20,
                          context=ssl.create_default_context()) as smtp:
        smtp.login(config["SMTP_USER"], config["SMTP_PASSWORD"])
        smtp.send_message(message)


async def process_one(store: Supabase, config: dict, sender=send) -> bool:
    job = await store.rpc("api_server_provider_mail", {"p_action": "lease"})
    if not job:
        return False
    result = "retry"
    try:
        message = compose(job, config["SMTP_FROM"], config["PROVIDER_PORTAL_ORIGIN"])
        await asyncio.to_thread(sender, message, config)
        result = "sent"
    except Exception:
        # Preserve the lease/retry protocol without logging provider information.
        pass
    await store.rpc("api_server_provider_mail", {"p_action": result, "p_id": job["id"], "p_lease": job["lease_id"]})
    return True


async def run(config: dict) -> None:
    for key in ("SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM", "PROVIDER_PORTAL_ORIGIN"):
        if not config.get(key):
            raise ValueError("mail_configuration_missing")
    clean_email(config["SMTP_FROM"])
    portal_url(config["PROVIDER_PORTAL_ORIGIN"])
    async with httpx.AsyncClient(trust_env=False, follow_redirects=False) as client:
        store = Supabase(config["SUPABASE_URL"], config["SUPABASE_SECRET_KEY"], client)
        processed = 0
        for _ in range(10):
            if not await process_one(store, config):
                break
            processed += 1
        print(json.dumps({"status": "complete", "processed": processed}))


def main() -> None:
    try:
        asyncio.run(run(dict(os.environ)))
    except Exception:
        print('{"status":"error","reason":"mail_worker_failed"}')
        raise SystemExit(1)


if __name__ == "__main__":
    main()
