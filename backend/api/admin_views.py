from datetime import timedelta, datetime
from django.shortcuts import render
from django.contrib.admin.views.decorators import staff_member_required
from django.utils.decorators import method_decorator
from django.views import View
from django.db.models import Sum, Count, Q
from django.db.models.functions import TruncMonth
from django.utils import timezone
from .models import Order, PayoutRequest, UserProfile, DeliveryLog, Kitchen


@method_decorator(staff_member_required, name='dispatch')
class DashboardView(View):
    template_name = 'admin/mealin_dashboard.html'

    def get(self, request):
        now = timezone.now()
        today = now.date()
        month_start = today.replace(day=1)
        year_start = today.replace(month=1, day=1)

        all_orders = Order.objects.all()
        delivered_orders = all_orders.filter(delivery_status='delivered')

        total_orders = all_orders.count()
        total_revenue = all_orders.aggregate(s=Sum('amount'))['s'] or 0
        total_delivery_fees = all_orders.aggregate(s=Sum('delivery_fee'))['s'] or 0
        today_orders = all_orders.filter(created_at__date=today).count()

        month_orders = all_orders.filter(created_at__date__gte=month_start)
        month_revenue = month_orders.aggregate(s=Sum('amount'))['s'] or 0
        month_delivery_fees = month_orders.aggregate(s=Sum('delivery_fee'))['s'] or 0

        year_orders = all_orders.filter(created_at__date__gte=year_start)
        year_revenue = year_orders.aggregate(s=Sum('amount'))['s'] or 0

        approved_payouts = PayoutRequest.objects.filter(status='approved')
        pending_payouts = PayoutRequest.objects.filter(status='pending')
        total_kitchen_payouts = approved_payouts.aggregate(s=Sum('amount'))['s'] or 0
        pending_kitchen_payouts = pending_payouts.aggregate(s=Sum('amount'))['s'] or 0

        dps = UserProfile.objects.filter(role='delivery_partner')
        total_dps = dps.count()
        active_dps = dps.filter(is_available=True).count()
        verified_dps = dps.filter(is_verified=True).count()

        dp_earnings = delivered_orders.values('delivery_partner__name', 'delivery_partner').annotate(
            earnings=Sum('delivery_fee'),
            deliveries=Count('id'),
        ).order_by('-earnings')[:20]

        platform_fees = total_revenue - total_delivery_fees - total_kitchen_payouts
        if platform_fees < 0:
            platform_fees = 0

        top_kitchens = all_orders.values('kitchen__name', 'kitchen').annotate(
            revenue=Sum('amount'),
            order_count=Count('id'),
        ).order_by('-revenue')[:10]

        recent_orders = all_orders.select_related('customer', 'kitchen', 'delivery_partner').order_by('-created_at')[:15]

        monthly = []
        for i in range(5, -1, -1):
            m_start = (month_start - timedelta(days=30 * i)).replace(day=1)
            if m_start.month == 12:
                m_end = m_start.replace(year=m_start.year + 1, month=1) - timedelta(days=1)
            else:
                m_end = m_start.replace(month=m_start.month + 1) - timedelta(days=1)
            qs = all_orders.filter(created_at__date__gte=m_start, created_at__date__lte=m_end)
            monthly.append({
                'label': m_start.strftime('%b %Y'),
                'revenue': float(qs.aggregate(s=Sum('amount'))['s'] or 0),
                'fees': float(qs.aggregate(s=Sum('delivery_fee'))['s'] or 0),
                'orders': qs.count(),
            })

        kitchen_payout_list = PayoutRequest.objects.select_related('chef').order_by('-requested_at')[:20]
        pending_payout_list = PayoutRequest.objects.filter(status='pending').select_related('chef').order_by('-requested_at')

        return render(request, self.template_name, {
            'title': 'Dashboard',
            'total_orders': total_orders,
            'total_revenue': total_revenue,
            'total_delivery_fees': total_delivery_fees,
            'today_orders': today_orders,
            'month_orders': month_orders.count(),
            'month_revenue': month_revenue,
            'month_delivery_fees': month_delivery_fees,
            'year_orders': year_orders.count(),
            'year_revenue': year_revenue,
            'total_kitchen_payouts': total_kitchen_payouts,
            'pending_kitchen_payouts': pending_kitchen_payouts,
            'payout_count': approved_payouts.count(),
            'total_dps': total_dps,
            'active_dps': active_dps,
            'verified_dps': verified_dps,
            'dp_earnings': dp_earnings,
            'platform_fees': platform_fees,
            'top_kitchens': top_kitchens,
            'recent_orders': recent_orders,
            'monthly_data': monthly,
            'kitchen_payout_list': kitchen_payout_list,
            'pending_payout_list': pending_payout_list,
        })


@method_decorator(staff_member_required, name='dispatch')
class KitchenReportView(View):
    template_name = 'admin/mealin_report.html'

    def get(self, request):
        kitchens = Kitchen.objects.all().annotate(
            total_orders=Count('orders'),
            total_revenue=Sum('orders__amount'),
            total_delivery_fees=Sum('orders__delivery_fee'),
        ).order_by('-total_revenue')

        for k in kitchens:
            k.payouts = PayoutRequest.objects.filter(chef=k.chef).aggregate(
                approved=Sum('amount', filter=Q(status='approved')),
                pending=Sum('amount', filter=Q(status='pending')),
            )
            k.net_earnings = (k.total_revenue or 0) - (k.total_delivery_fees or 0)

        return render(request, self.template_name, {
            'title': 'Kitchen Reports',
            'kitchens': kitchens,
            'total_kitchens': kitchens.count(),
            'total_kitchen_revenue': sum((k.total_revenue or 0) for k in kitchens),
            'total_payouts': PayoutRequest.objects.filter(status='approved').aggregate(s=Sum('amount'))['s'] or 0,
        })


@method_decorator(staff_member_required, name='dispatch')
class DeliveryPartnerReportView(View):
    template_name = 'admin/mealin_report.html'

    def get(self, request):
        dps = UserProfile.objects.filter(role='delivery_partner').annotate(
            total_deliveries=Count('delivery_orders', filter=Q(delivery_orders__delivery_status='delivered')),
            total_earnings=Sum('delivery_orders__delivery_fee', filter=Q(delivery_orders__delivery_status='delivered')),
        ).order_by('-total_earnings')

        return render(request, self.template_name, {
            'title': 'Delivery Partner Reports',
            'delivery_partners': dps,
            'total_dps': dps.count(),
            'total_dp_earnings': sum((d.total_earnings or 0) for d in dps),
            'total_deliveries': sum((d.total_deliveries or 0) for d in dps),
        })
