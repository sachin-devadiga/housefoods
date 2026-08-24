"""Safe migration management command that handles corrupted database state."""
import os
import sys
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Safe migrate that handles missing tables from wiped databases'

    def handle(self, *args, **options):
        self.stdout.write('Checking database state...')

        # Check if critical tables exist
        tables_needed = ['auth_user', 'django_migrations']
        missing = []
        with connection.cursor() as cursor:
            for table in tables_needed:
                cursor.execute(
                    "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = %s)",
                    [table]
                )
                exists = cursor.fetchone()[0]
                if not exists:
                    missing.append(table)
                    self.stdout.write(self.style.WARNING(f'  Table {table} is MISSING'))

        if missing:
            self.stdout.write(self.style.WARNING(
                f'Database appears wiped. Missing tables: {missing}. '
                'Resetting migration state...'
            ))

            # Fake unapply all known apps
            from django.core.management import call_command
            apps = ['token_blacklist', 'admin', 'sessions', 'contenttypes', 'auth', 'api']
            for app in apps:
                try:
                    call_command('migrate', app, 'zero', '--fake', verbosity=0)
                except Exception:
                    pass

            # Fake apply all
            try:
                call_command('migrate', '--fake', verbosity=0)
            except Exception:
                pass

        # Now do a real migrate
        self.stdout.write('Running migrate...')
        from django.core.management import call_command
        call_command('migrate', '--noinput', verbosity=1)
        self.stdout.write(self.style.SUCCESS('Migrations complete!'))
