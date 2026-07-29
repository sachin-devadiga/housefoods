import os
import json
import time
import threading
import logging
import smtplib
import urllib.request
import urllib.error
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

logger = logging.getLogger(__name__)

OTP_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'otp_output.txt')

_t0 = 0.0

def t0():
    global _t0
    _t0 = time.perf_counter()

def elapsed():
    return time.perf_counter() - _t0

def tlog(msg):
    print(f'[TIMING] [{elapsed():.3f}s] {msg}')
    logger.info(f'[{elapsed():.3f}s] {msg}')

def log(msg):
    print(f'[OTP] {msg}')
    logger.info(msg)


def check_env():
    api_key = os.getenv('BREVO_API_KEY', '')
    sender_email = os.getenv('BREVO_SENDER_EMAIL', '')
    sender_name = os.getenv('BREVO_SENDER_NAME', 'Housefoods')
    tlog(f'BREVO_API_KEY loaded: {"YES" if api_key else "NO"}')
    tlog(f'BREVO_SENDER_EMAIL: {sender_email}')
    tlog(f'BREVO_SENDER_NAME: {sender_name}')


def send_otp_email_async(email, otp_code):
    def send_with_logging():
        try:
            _send_otp_email_sync(email, otp_code)
        except Exception:
            # Never let a daemon-thread exception disappear silently. The API
            # response is already returned, so retain the full SMTP traceback
            # in the Django server log for diagnosis.
            logger.exception('OTP email delivery failed for %s', email)

    thread = threading.Thread(
        target=send_with_logging,
        daemon=True,
    )
    thread.start()
    tlog('Email thread dispatched to background')


def _send_otp_email_sync(email, otp_code):
    t0_inner = time.perf_counter()

    def ielapsed():
        return time.perf_counter() - t0_inner

    def itlog(msg):
        print(f'[TIMING] [{ielapsed():.3f}s] {msg}')

    itlog('Background email thread started')

    sender_name = os.getenv('BREVO_SENDER_NAME', 'Housefoods')
    sender_email = os.getenv('BREVO_SENDER_EMAIL', os.getenv('BREVO_FROM_EMAIL', ''))

    subject = 'Your HouseFoods OTP Code'
    text_content = (
        f'Your One-Time Password (OTP) for HouseFoods login is:\n\n'
        f'   {otp_code}\n\n'
        f'This code is valid for 5 minutes.\n'
        f'If you did not request this, please ignore this email.\n\n'
        f'Thank you,\nHouseFoods Team'
    )
    html_content = f'''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#f5f5f5;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:24px;">
<tr><td align="center">
<table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;">
<tr><td style="background:#FF6B35;padding:24px;text-align:center;">
<h1 style="color:#ffffff;margin:0;font-size:24px;">HouseFoods</h1>
</td></tr>
<tr><td style="padding:32px;">
<p style="color:#333;font-size:16px;margin:0 0 16px 0;">Your One-Time Password (OTP) for login is:</p>
<div style="text-align:center;margin:24px 0;padding:16px;background:#fff5f0;border-radius:8px;">
<span style="font-size:40px;font-weight:bold;letter-spacing:8px;color:#FF6B35;font-family:monospace;">{otp_code}</span>
</div>
<p style="color:#666;font-size:14px;margin:0;">This code is valid for <strong>5 minutes</strong>.</p>
<p style="color:#666;font-size:14px;margin:16px 0 0 0;">If you did not request this, please ignore this email.</p>
</td></tr>
<tr><td style="background:#fafafa;padding:16px;text-align:center;">
<p style="color:#999;font-size:12px;margin:0;">HouseFoods - Connecting home kitchens with customers</p>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>'''

    # Write OTP to file
    try:
        with open(OTP_FILE, 'a') as f:
            f.write(f'{email}: {otp_code}\n')
    except Exception as e:
        itlog(f'Failed to write OTP file: {e}')

    # Try REST API first (no IP restriction), fall back to SMTP
    api_key = os.getenv('BREVO_API_KEY', '')
    if api_key:
        itlog('Using Brevo REST API')
        ok = _send_via_rest_api(email, sender_name, sender_email, subject, text_content, html_content, api_key, itlog)
        if ok:
            itlog('Email sent via Brevo REST API')
            return
        itlog('REST API failed, falling back to SMTP')

    remote_smtp_host = os.getenv('BREVO_SMTP_HOST', 'smtp-relay.brevo.com')
    remote_smtp_port = int(os.getenv('BREVO_SMTP_PORT', '587'))
    smtp_user = os.getenv('BREVO_SMTP_USER', '')
    smtp_pass = os.getenv('BREVO_SMTP_PASSWORD', '')

    itlog(f'Connecting to SMTP {remote_smtp_host}:{remote_smtp_port}...')
    server = smtplib.SMTP(remote_smtp_host, remote_smtp_port, timeout=30)
    itlog('SMTP connected')

    server.starttls()
    itlog('TLS established')

    server.login(smtp_user, smtp_pass)
    itlog('SMTP authenticated')

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'{sender_name} <{sender_email}>'
    msg['To'] = email
    msg['Date'] = time.strftime('%a, %d %b %Y %H:%M:%S +0000', time.gmtime())
    msg['Message-ID'] = f'<{time.time():.0f}.{hash(email)}@housefoods.app>'
    msg['X-Mailer'] = 'HouseFoods OTP Service'
    msg.attach(MIMEText(text_content, 'plain'))
    msg.attach(MIMEText(html_content, 'html'))

    result = server.sendmail(sender_email, [email], msg.as_string())
    itlog('Email sent to SMTP server')

    server.quit()
    itlog('SMTP connection closed')

    if result:
        raise RuntimeError(f'SMTP failed for recipients: {result}')
    itlog('Email accepted by Brevo SMTP — queued for delivery')


def _send_via_rest_api(email, sender_name, sender_email, subject, text_content, html_content, api_key, tlog_fn):
    url = 'https://api.brevo.com/v3/smtp/email'

    payload = json.dumps({
        'sender': {'name': sender_name, 'email': sender_email},
        'to': [{'email': email}],
        'subject': subject,
        'htmlContent': html_content,
        'textContent': text_content,
    }).encode('utf-8')

    headers = {
        'Content-Type': 'application/json',
        'api-key': api_key,
        'Accept': 'application/json',
    }

    tlog_fn('Sending HTTP POST to Brevo REST API...')

    req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            status = response.status
            body = response.read().decode('utf-8')
            tlog_fn(f'Brevo REST API status: {status}')
            if status == 201:
                return True
            return False
    except urllib.error.HTTPError as e:
        status = e.code
        body = e.read().decode('utf-8')
        tlog_fn(f'Brevo REST API error: {status} {body}')
        return False
    except urllib.error.URLError as e:
        tlog_fn(f'Brevo REST API URL error: {e.reason}')
        return False
    except Exception as e:
        tlog_fn(f'Brevo REST API error: {e}')
        return False


# Backward-compatible synchronous wrapper
def send_otp_email(email, otp_code):
    _send_otp_email_sync(email, otp_code)
