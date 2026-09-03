"""Safe migration: drops django_migrations table if DB is corrupted, then migrates fresh."""
import os
import sys
from django.core.management.base import BaseCommand
from django.core.management import call_command
from django.db import connection


class Command(BaseCommand):
    help = 'Safe migrate that handles wiped databases by dropping migration history'

    def handle(self, *args, **options):
        self.stdout.write('Checking database state...')

        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'auth_user')"
            )
            auth_exists = cursor.fetchone()[0]

            if not auth_exists:
                self.stdout.write(self.style.WARNING(
                    'auth_user table MISSING. Dropping django_migrations to start fresh...'
                ))
                cursor.execute('DROP TABLE IF EXISTS django_migrations CASCADE')
                self.stdout.write(self.style.SUCCESS('Dropped django_migrations table.'))
            else:
                self.stdout.write('auth_user exists. Running normal migrate...')
                call_command('migrate', '--noinput', verbosity=1)
                self.stdout.write(self.style.SUCCESS('Done!'))
                self._seed_app_version()
                return

        self.stdout.write('Running fresh migrate...')
        call_command('migrate', '--noinput', verbosity=1)
        self.stdout.write(self.style.SUCCESS('Migrations complete!'))
        self._seed_app_version()

    def _seed_app_version(self):
        """Seed app version settings if they don't exist."""
        from api.models import AdminSetting

        defaults = {
            'app_latest_version': os.environ.get('APP_LATEST_VERSION', '1.0.3'),
            'app_min_version': os.environ.get('APP_MIN_VERSION', '1.0.0'),
            'app_update_url': os.environ.get('APP_UPDATE_URL', 'https://github.com/sachin-devadiga/housefoods/releases/download/v1.0.4'),
            'app_update_message': os.environ.get('APP_UPDATE_MESSAGE', ''),
            'app_force_update': os.environ.get('APP_FORCE_UPDATE', 'false'),
        }

        for key, default in defaults.items():
            obj, created = AdminSetting.objects.update_or_create(
                key=key, defaults={'value': default}
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created {key} = {default}'))
            else:
                self.stdout.write(f'Updated {key} = {default} (was {obj.value})')
