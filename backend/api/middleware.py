import logging
from django.http import HttpResponse

logger = logging.getLogger(__name__)


class ForceRenderMiddleware:
    """Force TemplateResponse.render() inside the middleware chain.

    Django 5.x changed when TemplateResponse.render() is called. Without
    this, the render may fail in the WSGI handler where exceptions cannot
    be caught, resulting in a generic 500 page. By forcing render here, any
    template errors are properly caught and surfaced.
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
                return HttpResponse(
                    '<h1>Server Error (500)</h1><p>Template rendering failed. Check server logs.</p>',
                    content_type='text/html',
                    status=500,
                )
        return response
