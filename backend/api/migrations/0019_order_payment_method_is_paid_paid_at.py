from django.db import migrations, models


def mark_existing_orders_paid(apps, schema_editor):
    """Backfill is_paid for orders created before this field existed.

    Every pre-existing order was placed through the Razorpay path, so they are
    all settled. Defaulting them to False would silently zero out historical
    chef earnings; leaving the column default at True keeps new COD orders
    correct only because their create path sets it explicitly.
    """
    Order = apps.get_model('api', 'Order')
    Order.objects.filter(is_paid=False, payment_method='online').update(is_paid=True)


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0018_seed_commerce_settings'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='payment_method',
            field=models.CharField(
                choices=[('online', 'Online'), ('cod', 'Cash on Delivery')],
                default='online', max_length=10,
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='is_paid',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='order',
            name='paid_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddIndex(
            model_name='order',
            index=models.Index(
                fields=['kitchen', 'is_paid'],
                name='api_order_kitchen_9d5f5e_idx',
            ),
        ),
        migrations.RunPython(mark_existing_orders_paid, migrations.RunPython.noop),
    ]