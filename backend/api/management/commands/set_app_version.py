from django.core.management.base import BaseCommand
from api.models import AdminSetting


class Command(BaseCommand):
    help = 'Set app version update settings'

    def add_arguments(self, parser):
        parser.add_argument('--latest', type=str, help='Latest app version (e.g. 1.0.1)')
        parser.add_argument('--min', type=str, dest='min_version', help='Min required version')
        parser.add_argument('--url', type=str, help='APK download URL')
        parser.add_argument('--message', type=str, help='Update message')
        parser.add_argument('--force', type=str, help='Force update (true/false)')

    def handle(self, *args, **options):
        updates = {}
        if options['latest']:
            updates['app_latest_version'] = options['latest']
        if options['min_version']:
            updates['app_min_version'] = options['min_version']
        if options['url']:
            updates['app_update_url'] = options['url']
        if options['message']:
            updates['app_update_message'] = options['message']
        if options['force']:
            updates['app_force_update'] = options['force'].lower()

        if not updates:
            self.stdout.write(self.style.WARNING('No options provided. Use --latest, --min, --url, --message, --force'))
            return

        for key, value in updates.items():
            obj, created = AdminSetting.objects.update_or_create(
                key=key, defaults={'value': value}
            )
            action = 'Created' if created else 'Updated'
            self.stdout.write(self.style.SUCCESS(f'{action} {key} = {value}'))

        self.stdout.write(self.style.SUCCESS('Done!'))
