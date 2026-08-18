import traceback
import logging
from django.http import HttpResponse

logger = logging.getLogger(__name__)


class DebugErrorMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        if not hasattr(response, 'render'):
            return response
        is_admin_change = (
            request.path.startswith('/admin/') and
            request.path.rstrip('/') != '/admin' and
            request.path.rstrip('/') != '/admin/'
        )
        if not is_admin_change:
            return response
        try:
            return response.render()
        except Exception:
            tb = traceback.format_exc()
            logger.error('Admin render error on %s: %s', request.path, tb)
            return HttpResponse(
                '<pre>' + tb + '</pre>',
                content_type='text/plain',
                status=500,
            )
