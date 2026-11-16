"""
Email utilities for AdviserLink.
Uses SMTP for sending verification and password reset emails.
Configure SMTP settings in .env (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM).
"""
import os
import smtplib
import ssl
from html import escape
from email.message import EmailMessage
from typing import Optional


# Load SMTP config from environment
SMTP_HOST = os.getenv("SMTP_HOST", "").strip()
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "").strip()
SMTP_PASS = os.getenv("SMTP_PASS", "").strip()
SMTP_FROM = os.getenv("SMTP_FROM", "").strip()
APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:5173").strip()

# Token storage for dev mode (when SMTP not configured)
# In production, use a proper database table for tokens
_DEV_TOKENS = {}


def _can_send() -> bool:
    """Check if SMTP is configured."""
    return all([SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM])


def _store_dev_token(email: str, token: str, purpose: str) -> None:
    """Store token for dev mode (when SMTP not configured)."""
    _DEV_TOKENS[f"{purpose}:{email.lower()}"] = {
        "token": token,
        "email": email.lower(),
        "purpose": purpose
    }
    print(f"\n[DEV MODE] {purpose.upper()} token for {email}: {token}")
    print(f"[DEV MODE] Verification URL: {APP_BASE_URL}/{purpose}?token={token}\n")


def _get_dev_token(email: str, purpose: str) -> Optional[str]:
    """Get stored dev token."""
    return _DEV_TOKENS.get(f"{purpose}:{email.lower()}", {}).get("token")


def send_email(to: str, subject: str, html: str, text: Optional[str] = None) -> bool:
    """
    Send an email via SMTP. Returns True on success, False on failure.
    Silently fails if SMTP is not configured (for development).
    """
    if not _can_send():
        print(f"[Email] SMTP not configured. Would send to {to}: {subject}")
        return False

    try:
        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = SMTP_FROM
        msg["To"] = to
        if text:
            msg.set_content(text)
        msg.add_alternative(html, subtype="html")

        context = ssl.create_default_context()
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls(context=context)
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        return True
    except Exception as e:
        print(f"[Email] Failed to send to {to}: {e}")
        return False


def _send_or_store(to: str, name: str, token: str, purpose: str, subject: str, html: str, text: str) -> bool:
    """Send email only when SMTP is configured; development tokens are handled by callers."""
    if _can_send():
        return send_email(to, subject, html, text)
    return False


def send_verification_email(email: str, name: str, token: str) -> bool:
    """Send email verification link."""
    verify_url = f"{APP_BASE_URL}/verify-email?token={token}"
    subject = "Verify your AdviserLink account"
    safe_name = escape(name)
    html = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 24px;">AdviserLink</h1>
        </div>
        <div style="background: #fff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 12px 12px;">
            <h2 style="color: #1f2937; margin-top: 0;">Verify your email address</h2>
            <p>Hi <strong>{safe_name}</strong>,</p>
            <p>Thanks for registering! Please verify your email address by clicking the button below:</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="{verify_url}" style="display: inline-block; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); color: white; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: 600;">Verify Email</a>
            </div>
            <p style="color: #6b7280; font-size: 14px;">Or copy this link: <a href="{verify_url}">{verify_url}</a></p>
            <p style="color: #6b7280; font-size: 14px;">This link expires in 24 hours. If you didn't create an account, you can ignore this email.</p>
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
            <p style="color: #9ca3af; font-size: 12px;">AdviserLink — Thesis & Capstone Advising Platform</p>
        </div>
    </body>
    </html>
    """
    text = f"Verify your AdviserLink account\n\nHi {name},\n\nPlease verify your email: {verify_url}\n\nThis link expires in 24 hours."
    return _send_or_store(email, name, token, "verify-email", subject, html, text)


def send_password_reset_email(email: str, name: str, token: str) -> bool:
    """Send password reset link."""
    reset_url = f"{APP_BASE_URL}/reset-password?token={token}"
    subject = "Reset your AdviserLink password"
    safe_name = escape(name)
    html = f"""
    <!DOCTYPE html>
    <html>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 24px;">AdviserLink</h1>
        </div>
        <div style="background: #fff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 12px 12px;">
            <h2 style="color: #1f2937; margin-top: 0;">Reset your password</h2>
            <p>Hi <strong>{safe_name}</strong>,</p>
            <p>You requested to reset your password. Click the button below to create a new one:</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="{reset_url}" style="display: inline-block; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); color: white; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: 600;">Reset Password</a>
            </div>
            <p style="color: #6b7280; font-size: 14px;">Or copy this link: <a href="{reset_url}">{reset_url}</a></p>
            <p style="color: #6b7280; font-size: 14px;">This link expires in 1 hour. If you didn't request this, you can ignore this email.</p>
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
            <p style="color: #9ca3af; font-size: 12px;">AdviserLink — Thesis & Capstone Advising Platform</p>
        </div>
    </body>
    </html>
    """
    text = f"Reset your AdviserLink password\n\nHi {name},\n\nReset your password: {reset_url}\n\nThis link expires in 1 hour."
    return _send_or_store(email, name, token, "reset-password", subject, html, text)


# Dev mode helper: get stored token
def get_dev_token(email: str, purpose: str) -> Optional[str]:
    """Get stored dev token for testing."""
    return _get_dev_token(email, purpose)