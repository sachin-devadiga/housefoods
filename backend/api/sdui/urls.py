from django.urls import path

from . import views

urlpatterns = [
    path('bootstrap/', views.BootstrapView.as_view(), name='sdui-bootstrap'),
    path('screens/<str:key>/', views.ScreenView.as_view(), name='sdui-screen'),
    path('manifest/', views.ManifestView.as_view(), name='sdui-manifest'),
]