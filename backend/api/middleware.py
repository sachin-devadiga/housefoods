import logging
from django.conf import settings
from django.http import HttpResponse

logger = logging.getLogger(__name__)


class ForceRenderMiddleware:
    """Force TemplateResponse.render() inside the middleware chain.

    Django 5.x changed when TemplateResponse.render() is called. Without
    this, the render may fail in the WSGI handler where exceptions cannot
    be caught, resulting in a generic 500 page. By forcing render here, any
    template errors are properly caught and surfaced.

    With DEBUG=True the original exception is re-raised so Django shows its
    normal traceback page; in production a generic 500 is returned instead
    (no internals leak to browsers).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        if hasattr(response, 'render') and callable(response.render):
            try:
                response = response.render()
            except Exception:
                logger.exception('Template render failed for %s', request.path)
                if settings.DEBUG:
                    raise
                return HttpResponse(
                    '<h1>Server Error (500)</h1><p>Template rendering failed. Check server logs.</p>',
                    content_type='text/html',
                    status=500,
                )
        return response
