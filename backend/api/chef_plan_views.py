"""Chef-facing meal-plan management.

Closes a real gap: `lib/core/constants/app_constants.dart` declares
`chefMealPlansEndpoint` and `chefPlanSubscribersEndpoint`, and
`MealPlanProvider.savePlan` is a documented no-op because neither existed.

Kept in its own module rather than appended to `subscription_views.py`, which is
explicitly customer-scoped. The split matters for review: this file has one job
and one set of permission rules.

Ownership is the whole point of this module. Every queryset is filtered through
[_chef_kitchens], so a chef can only ever see or mutate plans belonging to a
kitchen they own. `tests_chef_plans.py` asserts cross-kitchen access is
refused, because that is the failure that would actually hurt someone.
"""

import logging

from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Kitchen, MealPlan, PlanPrice, Subscription
from .serializers import MealPlanSerializer, MealPlanWriteSerializer

logger = logging.getLogger(__name__)


def _chef_kitchens(request):
    """Kitchens the authenticated user actually owns.

    Follows the existing convention (`request.user.profile`, as used in
    views.py and subscription_views.py) rather than re-deriving it.

    Empty for a non-chef, which the views turn into a 403 rather than an empty
    200 — "you have no plans" and "you are not allowed to ask" are different
    answers and conflating them hides the authorisation bug.
    """
    profile = getattr(request.user, 'profile', None)
    if profile is None or profile.role != 'chef':
        return Kitchen.objects.none()
    return Kitchen.objects.filter(chef=profile)


def _int_param(raw, default, minimum=1):
    """Parse a positive int query param, or None if unusable."""
    if raw is None or raw == '':
        return default
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return None
    return value if value >= minimum else None


def _bad_page_params():
    return Response(
        {'detail': 'page and page_size must be positive integers.'},
        status=status.HTTP_400_BAD_REQUEST,
    )


def _deny_non_chef(kitchens):
    """403 payload used when the caller owns no kitchen."""
    return Response(
        {'detail': 'Only kitchen accounts can manage meal plans.'},
        status=status.HTTP_403_FORBIDDEN,
    )


class _ChefPlanBase(APIView):
    permission_classes = [IsAuthenticated]

    def _scope(self, request):
        """Return the chef's plan queryset, or a Response to return instead."""
        kitchens = _chef_kitchens(request)
        if not kitchens.exists():
            return _deny_non_chef(kitchens)
        return MealPlan.objects.filter(kitchen__in=kitchens)


class ChefMealPlanListCreateView(_ChefPlanBase):
    """GET the chef's own plans; POST a new draft.

    Drafts are created with ``is_active=False``. A chef builds a plan, fills in
    prices and slots, and publishes explicitly — an accidentally-live empty plan
    would be visible to customers and could be subscribed to.
    """

    def get(self, request):
        queryset = self._scope(request)
        if isinstance(queryset, Response):
            return queryset
        plans = queryset.select_related('kitchen').prefetch_related(
            'prices', 'slots',
        ).order_by('-updated_at')

        # Paginated envelope rather than a bare array, so this matches
        # `subscriptionPlansEndpoint` and the client's `data['results']` parse.
        page = _int_param(request.query_params.get('page'), 1, minimum=1)
        page_size = _int_param(request.query_params.get('page_size'), 20, minimum=1)
        if page is None or page_size is None:
            return _bad_page_params()
        page_size = min(page_size, 100)

        total = plans.count()
        start = (page - 1) * page_size
        rows = plans[start:start + page_size]
        return Response({
            'count': total,
            'page': page,
            'page_size': page_size,
            'has_next': start + page_size < total,
            'results': MealPlanSerializer(rows, many=True).data,
        })

    def post(self, request):
        queryset = self._scope(request)
        if isinstance(queryset, Response):
            return queryset

        # A chef may only create under a kitchen they own. Accepting a
        # `kitchen` id from the client without checking would let any chef
        # attach a plan to a competitor's kitchen.
        kitchen_id = request.data.get('kitchen')
        try:
            kitchen = _chef_kitchens(request).get(pk=kitchen_id)
        except (TypeError, ValueError):
            return Response(
                {'detail': 'A valid kitchen id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Kitchen.DoesNotExist:
            # Same response as an unknown id, so this cannot be used to probe
            # which kitchen ids exist.
            return Response(
                {'detail': 'Unknown or inaccessible kitchen.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        payload = {k: v for k, v in request.data.items() if k != 'kitchen'}
        # Force draft regardless of what the client asked for.
        payload['is_active'] = False

        serializer = MealPlanWriteSerializer(data=payload)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            plan = serializer.save(kitchen=kitchen)

        return Response(
            MealPlanSerializer(plan).data, status=status.HTTP_201_CREATED,
        )


class ChefMealPlanDetailView(_ChefPlanBase):
    """Read / update / delete one of the chef's plans.

    PATCH with ``{"is_active": true}`` publishes; ``false`` unpublishes.
    """

    def _get(self, request, pk):
        queryset = self._scope(request)
        if isinstance(queryset, Response):
            return queryset, None
        plan = queryset.filter(pk=pk).first()
        if plan is None:
            # 404, not 403: the plan does not exist *for this chef*. Returning
            # 403 would confirm that somebody else's plan exists at that id.
            return None, Response(
                {'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND,
            )
        return plan, None

    def get(self, request, pk):
        plan, error = self._get(request, pk)
        if error is not None:
            return error
        return Response(MealPlanSerializer(plan).data)

    def patch(self, request, pk):
        plan, error = self._get(request, pk)
        if error is not None:
            return error

        # `kitchen` is never reassignable: moving a plan to another kitchen
        # would silently transfer subscribers.
        payload = {k: v for k, v in request.data.items() if k != 'kitchen'}

        serializer = MealPlanWriteSerializer(plan, data=payload, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            serializer.save()

        plan.refresh_from_db()
        return Response(MealPlanSerializer(plan).data)

    def delete(self, request, pk):
        plan, error = self._get(request, pk)
        if error is not None:
            return error

        # `Subscription.plan` is on_delete=PROTECT, so deleting a plan that
        # has subscribers raises ProtectedError. Surface that as a 409 with an
        # explanation rather than a 500.
        if plan.subscriptions.exists():
            return Response(
                {
                    'detail': 'This plan has active subscribers and cannot be '
                              'deleted. Unpublish it instead.',
                    'subscriber_count': plan.subscriptions.count(),
                },
                status=status.HTTP_409_CONFLICT,
            )

        with transaction.atomic():
            plan.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChefPlanSubscribersListView(_ChefPlanBase):
    """Paginated subscribers for one of the chef's plans."""

    def get(self, request, pk):
        queryset = self._scope(request)
        if isinstance(queryset, Response):
            return queryset

        plan = queryset.filter(pk=pk).first()
        if plan is None:
            return Response(
                {'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND,
            )

        subs = (
            Subscription.objects
            .filter(plan=plan)
            .select_related('customer', 'address')
            .order_by('-id')
        )

        page = _int_param(request.query_params.get('page'), 1)
        page_size = _int_param(request.query_params.get('page_size'), 20)
        if page is None or page_size is None:
            return _bad_page_params()
        page_size = min(page_size, 100)

        total = subs.count()
        start = (page - 1) * page_size
        rows = subs[start:start + page_size]

        data = [
            {
                'id': s.id,
                'status': s.status,
                'cadence': s.cadence,
                'price_paid': str(s.price_paid),
                'start_date': s.start_date,
                'end_date': s.end_date,
                'customer_uid': s.customer.uid,
                'customer_name': s.customer.name,
                'customer_phone': s.customer.phone,
                'address': s.address.address_line1,
            }
            for s in rows
        ]

        return Response({
            'count': total,
            'page': page,
            'page_size': page_size,
            'has_next': start + page_size < total,
            'results': data,
        })


class ChefSubscribersListView(_ChefPlanBase):
    """Every subscriber across all of the chef's plans."""

    def get(self, request):
        queryset = self._scope(request)
        if isinstance(queryset, Response):
            return queryset

        plan_ids = queryset.values_list('id', flat=True)
        subs = (
            Subscription.objects
            .filter(plan_id__in=plan_ids)
            .select_related('customer', 'plan', 'address')
            .order_by('-start_date')
        )

        page = _int_param(request.query_params.get('page'), 1)
        page_size = _int_param(request.query_params.get('page_size'), 20)
        if page is None or page_size is None:
            return _bad_page_params()
        page_size = min(page_size, 100)

        total = subs.count()
        start = (page - 1) * page_size
        rows = subs[start:start + page_size]

        return Response({
            'count': total,
            'page': page,
            'page_size': page_size,
            'has_next': start + page_size < total,
            'results': [
                {
                    'id': s.id,
                    'status': s.status,
                    'cadence': s.cadence,
                    'plan_id': s.plan_id,
                    'plan_name': s.plan.name,
                    'price_paid': str(s.price_paid),
                    'start_date': s.start_date,
                    'customer_uid': s.customer.uid,
                    'customer_name': s.customer.name,
                }
                for s in rows
            ],
        })


class ChefPlanCadencesView(APIView):
    """Cadence vocabulary.

    Cadence is data rather than code (`PlanPrice.CADENCE_CHOICES`), but the
    client still needs to know the legal set and the derived duration. Chefs
    cannot subscribe, but this stays `AllowAny`-free for consistency: it
    returns public vocabulary, and requires auth so it is not a free endpoint.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({
            'cadences': [
                {
                    'value': value,
                    'label': label,
                    'duration_days': PlanPrice.DURATION_DAYS[value],
                }
                for value, label in PlanPrice.CADENCE_CHOICES
            ],
            'meal_types': [
                {'value': v, 'label': lbl}
                for v, lbl in [
                    ('breakfast', 'Breakfast'),
                    ('lunch', 'Lunch'),
                    ('dinner', 'Dinner'),
                ]
            ],
        })