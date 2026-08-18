from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Create default admin superuser if it does not exist'

    def handle(self, *args, **options):
        username = 'admin'
        email = 'admin@mealin.app'
        password = 'admin123'

        if User.objects.filter(username=username).exists():
            user = User.objects.get(username=username)
            if not user.is_superuser:
                user.is_staff = True
                user.is_superuser = True
                user.set_password(password)
                user.save()
                self.stdout.write(self.style.SUCCESS(f'Upgraded {username} to superuser'))
            else:
                self.stdout.write(self.style.WARNING(f'User {username} already exists'))
            return

        existing = User.objects.filter(is_superuser=True).first()
        if existing:
            existing.username = username
            existing.email = email
            existing.set_password(password)
            existing.is_staff = True
            existing.is_superuser = True
            existing.save()
            self.stdout.write(self.style.SUCCESS(f'Renamed superuser to: {username} / {password}'))
            return

        User.objects.create_superuser(
            username=username,
            email=email,
            password=password,
        )
        self.stdout.write(self.style.SUCCESS(f'Superuser created: {username} / {password}'))
