import logging
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include
from api.admin_views import DashboardView, KitchenReportView, DeliveryPartnerReportView

logger = logging.getLogger(__name__)

urlpatterns = [
    path('admin/dashboard/', DashboardView.as_view(), name='admin_dashboard'),
    path('admin/reports/kitchens/', KitchenReportView.as_view(), name='admin_kitchen_report'),
    path('admin/reports/delivery-partners/', DeliveryPartnerReportView.as_view(), name='admin_dp_report'),
    # Keep the built-in admin route after the custom admin pages above.
    path('admin/', admin.site.urls),
    path('api/auth/', include('api.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
