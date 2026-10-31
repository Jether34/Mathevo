import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from html import escape
from pathlib import Path

from .config import settings

logger = logging.getLogger("mathevo.mail")
_LOGO_PATH = Path(__file__).parent / "assets" / "mathevo-logo.png"


class MailDeliveryError(Exception):
    pass


def send_verification_code(
    recipient: str,
    display_name: str,
    code: str,
    *,
    password_reset: bool = False,
) -> None:
    if not settings.smtp_configured:
        raise MailDeliveryError("Email delivery is not configured.")
    if not _LOGO_PATH.is_file():
        raise MailDeliveryError("The email brand image is missing.")

    purpose = "reset your password" if password_reset else "verify your email"
    subject = "Mathevo password reset code" if password_reset else "Mathevo email verification code"
    safe_name = escape(display_name or "Mathevo user")
    text = (
        f"Hello {display_name or 'Mathevo user'},\n\n"
        f"Use this six-digit code to {purpose}: {code}\n\n"
        f"This code expires in {settings.verification_code_minutes} minutes. "
        "If you did not request this, you can ignore this email.\n\n"
        "Mathevo\nDeveloper: Jether Garque"
    )
    html = f"""\
<!doctype html>
<html><body style="margin:0;background:#f3f5f8;font-family:Arial,sans-serif;color:#17223b">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 12px">
<tr><td align="center">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #e2e8f0;border-radius:18px;overflow:hidden">
<tr><td align="center" style="padding:28px 24px 12px">
<img src="cid:mathevo-logo" width="88" height="88" alt="Mathevo logo" style="display:block;object-fit:contain">
<h1 style="margin:14px 0 0;font-size:26px">Mathevo</h1>
<p style="margin:6px 0 0;color:#64748b">Calculate · Learn · Grow</p>
</td></tr>
<tr><td style="padding:20px 32px 30px">
<p style="font-size:16px">Hello {safe_name},</p>
<p style="font-size:15px;line-height:1.6">Use this code to {purpose}.</p>
<div style="margin:24px 0;padding:18px;text-align:center;background:#f1f5ff;border-radius:12px;font-size:34px;font-weight:700;letter-spacing:10px;color:#2563eb">{code}</div>
<p style="font-size:14px;line-height:1.6;color:#475569">This code expires in {settings.verification_code_minutes} minutes. If you did not request this, you can ignore this email.</p>
</td></tr>
<tr><td style="padding:18px 24px;background:#f8fafc;border-top:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px;line-height:1.7">
<strong style="color:#17223b">Mathevo</strong><br>
Developer: Jether Garque<br>
This message was sent to verify your Mathevo account.
</td></tr>
</table>
</td></tr></table>
</body></html>"""

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = formataddr((settings.smtp_from_name, settings.smtp_from_email))
    message["To"] = recipient
    message.set_content(text)
    message.add_alternative(html, subtype="html")
    html_part = message.get_body(preferencelist=("html",))
    assert html_part is not None
    html_part.add_related(
        _LOGO_PATH.read_bytes(),
        maintype="image",
        subtype="png",
        cid="mathevo-logo",
        filename="mathevo-logo.png",
        disposition="inline",
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as client:
            client.ehlo()
            client.starttls(context=ssl.create_default_context())
            client.ehlo()
            client.login(settings.smtp_username, settings.smtp_password)
            client.send_message(message)
    except (OSError, smtplib.SMTPException) as error:
        logger.warning(
            "SMTP delivery failed (%s, status=%s)",
            type(error).__name__,
            getattr(error, "smtp_code", "unavailable"),
        )
        raise MailDeliveryError("Email could not be sent. Try again shortly.") from None
