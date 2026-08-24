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
            # Check if auth_user table exists
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
                return

        # Run migrations from scratch
        self.stdout.write('Running fresh migrate...')
        call_command('migrate', '--noinput', verbosity=1)
        self.stdout.write(self.style.SUCCESS('Migrations complete!'))
