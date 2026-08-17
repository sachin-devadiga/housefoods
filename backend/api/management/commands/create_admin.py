from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Create default admin superuser if it does not exist'

    def handle(self, *args, **options):
        username = 'admin'
        email = 'admin@mealin.app'
        password = 'admin123'

        # Delete old superuser with email as username if exists
        old = User.objects.filter(email=email, username=email).first()
        if old and not User.objects.filter(username=username).exists():
            old.username = username
            old.set_password(password)
            old.save()
            self.stdout.write(self.style.SUCCESS(f'Updated existing superuser to: {username} / {password}'))
            return

        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(f'User {username} already exists'))
            return

        User.objects.create_superuser(
            username=username,
            email=email,
            password=password,
        )
        self.stdout.write(self.style.SUCCESS(f'Superuser created: {username} / {password}'))
