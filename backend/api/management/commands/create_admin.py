from django.core.management.base import BaseCommand
import os

from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Create an initial admin from environment variables (never resets one)'

    def handle(self, *args, **options):
        if User.objects.filter(is_superuser=True).exists():
            self.stdout.write('A superuser already exists; no changes made.')
            return

        username = os.getenv('DJANGO_SUPERUSER_USERNAME')
        email = os.getenv('DJANGO_SUPERUSER_EMAIL')
        password = os.getenv('DJANGO_SUPERUSER_PASSWORD')
        if not all((username, email, password)):
            self.stdout.write('No superuser created: set DJANGO_SUPERUSER_USERNAME, DJANGO_SUPERUSER_EMAIL, and DJANGO_SUPERUSER_PASSWORD.')
            return

        User.objects.create_superuser(username=username, email=email, password=password)
        self.stdout.write(self.style.SUCCESS(f'Superuser {username!r} created.'))
