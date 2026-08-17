import logging
import traceback

logger = logging.getLogger(__name__)


class AdminDebugMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        return response

    def process_view(self, request, view_func, view_args, view_kwargs):
        return None

    def process_exception(self, request, exception):
        tb = traceback.format_exc()
        logger.error('500 error on %s %s: %s', request.method, request.path, tb)
        from django.http import HttpResponseServerError
        return HttpResponseServerError(f'<pre>{tb}</pre>')
