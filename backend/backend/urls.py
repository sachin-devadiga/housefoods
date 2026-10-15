import logging
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include, re_path
from django.views.static import serve
from api.admin_views import DashboardView, KitchenReportView, DeliveryPartnerReportView

logger = logging.getLogger(__name__)

MEDIA_PATTERNS = static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
if not settings.DEBUG:
    # static() returns [] unless DEBUG is True, so uploaded images (recipe
    # photos, kitchen photos, avatars) would 404 in production. The GoDaddy
    # stack papered over this with an .htaccess rewrite; the Docker/Caddy stack
    # has no equivalent, so serve MEDIA_ROOT from Django instead.
    # ponytail: Django serves the bytes here, which costs a Gunicorn worker per
    # image. Move to a Caddy `file_server` on /media/* when traffic justifies it.
    MEDIA_PATTERNS += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]

urlpatterns = [
    path('admin/dashboard/', DashboardView.as_view(), name='admin_dashboard'),
    path('admin/reports/kitchens/', KitchenReportView.as_view(), name='admin_kitchen_report'),
    path('admin/reports/delivery-partners/', DeliveryPartnerReportView.as_view(), name='admin_dp_report'),
    # Keep the built-in admin route after the custom admin pages above.
    path('admin/', admin.site.urls),
    path('api/auth/', include('api.urls')),
] + MEDIA_PATTERNS
