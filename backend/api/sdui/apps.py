from django.apps import AppConfig


class SduiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api.sdui'
    label = 'sdui'
    verbose_name = 'Server-Driven UI'