from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Create default admin superuser if it does not exist'

    def handle(self, *args, **options):
        email = 'admin@mealin.app'
        if User.objects.filter(email=email).exists():
            self.stdout.write(self.style.WARNING(f'User {email} already exists'))
            return
        User.objects.create_superuser(
            username=email,
            email=email,
            password='admin123',
        )
        self.stdout.write(self.style.SUCCESS(f'Superuser created: {email} / admin123'))
