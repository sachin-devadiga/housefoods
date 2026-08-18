import traceback
import logging
from django.http import HttpResponse

logger = logging.getLogger(__name__)


class DebugErrorMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        if request.path.startswith('/admin/') and not request.path.startswith('/admin/login'):
            tb = traceback.format_exc()
            logger.error('Admin error on %s: %s', request.path, tb)
            return HttpResponse('<pre>' + tb + '</pre>', content_type='text/plain', status=500)
        return None
