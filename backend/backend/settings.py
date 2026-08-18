import os
from pathlib import Path
from datetime import timedelta
import dj_database_url
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'change-this-in-production')

DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'

ALLOWED_HOSTS = [
    host.strip()
    for host in os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
    if host.strip()
]
if render_hostname := os.getenv('RENDER_EXTERNAL_HOSTNAME'):
    ALLOWED_HOSTS.append(render_hostname)

CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.getenv('CSRF_TRUSTED_ORIGINS', '').split(',')
    if origin.strip()
]
if render_hostname:
    CSRF_TRUSTED_ORIGINS.append(f'https://{render_hostname}')

INSTALLED_APPS = [
    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'api',
]

# Jazzmin Admin Theme
JAZZMIN_SETTINGS = {
    'site_title': 'Mealin Admin',
    'site_header': 'Mealin',
    'site_brand': '🏠 Mealin',
    'welcome_sign': 'Welcome to Mealin Admin Panel',
    'copyright': 'Mealin',
    'search_model': ['api.UserProfile', 'api.Kitchen', 'api.Order'],
    'topmenu_links': [
        {'name': '📊 Dashboard', 'url': 'admin_dashboard', 'permissions': ['auth.view_user']},
        {'name': '📋 Kitchen Report', 'url': 'admin_kitchen_report', 'permissions': ['auth.view_user']},
        {'name': '🚚 DP Report', 'url': 'admin_dp_report', 'permissions': ['auth.view_user']},
        {'model': 'api.UserProfile'},
        {'model': 'api.Order'},
        {'model': 'api.Kitchen'},
    ],
    'usermenu_links': [
        {'name': 'View Site', 'url': '/', 'new_window': True},
    ],
    'show_sidebar': True,
    'navigation_expanded': True,
    'hide_apps': ['auth', 'contenttypes'],
    'hide_models': ['auth.Group', 'auth.User'],
    'order_with_respect_to': ['api.UserProfile', 'api.Address', 'api.Kitchen', 'api.KitchenCategory', 'api.MenuCategory', 'api.MenuItem', 'api.SubscriptionPlan', 'api.DailyMenu', 'api.Order', 'api.DeliveryLog', 'api.Payment', 'api.PayoutRequest', 'api.Review', 'api.Coupon', 'api.DeliveryDocument', 'api.SupportTicket', 'api.WalletTransaction', 'api.Banner', 'api.AdminSetting'],
    'changeform_format': 'horizontal_tabs',
    'changeform_format_overrides': {
        'api.UserProfile': 'single',
        'api.AdminSetting': 'single',
    },
    'icons': {
        'auth.User': 'fas fa-user',
        'api.UserProfile': 'fas fa-users',
        'api.Address': 'fas fa-map-marker-alt',
        'api.Kitchen': 'fas fa-utensils',
        'api.KitchenImage': 'fas fa-image',
        'api.KitchenCategory': 'fas fa-tags',
        'api.MenuCategory': 'fas fa-list',
        'api.MenuItem': 'fas fa-hamburger',
        'api.SubscriptionPlan': 'fas fa-calendar-alt',
        'api.DailyMenu': 'fas fa-calendar-day',
        'api.Order': 'fas fa-shopping-cart',
        'api.DeliveryLog': 'fas fa-truck',
        'api.Payment': 'fas fa-credit-card',
        'api.WalletTransaction': 'fas fa-wallet',
        'api.Review': 'fas fa-star',
        'api.Coupon': 'fas fa-percent',
        'api.SupportTicket': 'fas fa-headset',
        'api.Banner': 'fas fa-images',
        'api.AdminSetting': 'fas fa-cog',
        'api.PayoutRequest': 'fas fa-money-bill-wave',
        'api.DeliveryDocument': 'fas fa-id-card',
    },
}

JAZZMIN_UI_TWEAKS = {
    'navbar_small_text': False,
    'footer_small_text': False,
    'body_small_text': False,
    'brand_small_text': False,
    'brand_colour': 'navbar-dark',
    'accent': 'accent-primary',
    'navbar': 'navbar-dark navbar-dark',
    'no_navbar_border': False,
    'navbar_fixed': True,
    'layout_boxed': False,
    'footer_fixed': False,
    'sidebar_fixed': True,
    'sidebar': 'sidebar-dark-primary',
    'sidebar_nav_small_text': False,
    'sidebar_disable_expand': False,
    'sidebar_nav_child_indent': True,
    'sidebar_nav_compact_style': False,
    'sidebar_nav_legacy_style': False,
    'sidebar_nav_flat_style': False,
    'theme': 'darkly',
    'default_theme_mode': 'dark',
    'button_classes': {
        'primary': 'btn-primary',
        'secondary': 'btn-secondary',
        'info': 'btn-info',
        'warning': 'btn-warning',
        'danger': 'btn-danger',
        'success': 'btn-success',
    },
}

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

# PostgreSQL database. Render supplies DATABASE_URL; the individual variables
# keep local development with an existing PostgreSQL instance working.
DATABASE_URL = os.getenv('DATABASE_URL')
if DATABASE_URL:
    DATABASES = {'default': dj_database_url.config(conn_max_age=600)}
else:
    DATABASES = {'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'mealin'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'postgres'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }}

AUTH_PASSWORD_VALIDATORS = []

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'api.authentication.CustomJWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DATETIME_FORMAT': '%Y-%m-%d %H:%M:%S',
    'DATE_FORMAT': '%Y-%m-%d',
    'COERCE_DECIMAL_TO_STRING': False,
}

# SimpleJWT
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=int(os.getenv('JWT_ACCESS_TOKEN_LIFETIME_DAYS', '30'))),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=int(os.getenv('JWT_REFRESH_TOKEN_LIFETIME_DAYS', '90'))),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
}

# CORS is not required by the APK, but is needed for any browser client.
# Keep it open only in local development; set CORS_ALLOWED_ORIGINS in Render
# if you later host a web frontend.
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv('CORS_ALLOWED_ORIGINS', '').split(',')
    if origin.strip()
]
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.StaticFilesStorage'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Render terminates HTTPS at its proxy before forwarding to Gunicorn.
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '31536000'))
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'WARNING',
        },
        'api': {
            'handlers': ['console'],
            'level': 'INFO',
        },
    },
}

# Brevo SMTP Configuration
EMAIL_BACKEND = os.getenv(
    'EMAIL_BACKEND',
    'django.core.mail.backends.smtp.EmailBackend' if os.getenv('BREVO_SMTP_HOST') else 'django.core.mail.backends.console.EmailBackend',
)
EMAIL_HOST = os.getenv('BREVO_SMTP_HOST', 'smtp-relay.brevo.com')
EMAIL_PORT = int(os.getenv('BREVO_SMTP_PORT', '587'))
EMAIL_USE_TLS = os.getenv('BREVO_SMTP_TLS', 'True').lower() == 'true'
EMAIL_HOST_USER = os.getenv('BREVO_SMTP_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('BREVO_SMTP_PASSWORD', '')
BREVO_SENDER_NAME = os.getenv('BREVO_SENDER_NAME', 'Mealin')
BREVO_SENDER_EMAIL = os.getenv('BREVO_SENDER_EMAIL', os.getenv('BREVO_FROM_EMAIL', ''))
DEFAULT_FROM_EMAIL = f'{BREVO_SENDER_NAME} <{BREVO_SENDER_EMAIL}>'
