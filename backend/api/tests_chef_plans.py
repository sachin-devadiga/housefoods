"""Chef meal-plan CRUD tests.

The cases that matter are the negative ones. A chef being able to read or write
another kitchen's plan is the bug that would actually hurt someone, so those are
asserted explicitly rather than assumed from the queryset filters.

Follows the `_mkuser` + `APIClient.force_authenticate` pattern already used in
tests_rider_payout.py, so it needs no shared base class.
"""
from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from api.models import Address, Kitchen, MealPlan, Subscription, UserProfile


def _mkuser(email, role):
    return UserProfile.objects.create(
        user=User.objects.create_user(username=email, email=email, password='x'),
        email=email, name=email.split('@')[0], role=role,
    )


class ChefPlanTestBase(TestCase):
    """Two chefs, two kitchens, so cross-access is testable."""

    def setUp(self):
        super().setUp()
        self.chef = _mkuser('chef-one@p.dev', 'chef')
        self.other_chef = _mkuser('chef-two@p.dev', 'chef')
        self.customer = _mkuser('cust-one@p.dev', 'customer')

        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='Chef One Kitchen', status='approved',
            latitude=12.97, longitude=77.59,
        )
        self.other_kitchen = Kitchen.objects.create(
            chef=self.other_chef, name='Chef Two Kitchen', status='approved',
            latitude=13.00, longitude=77.60,
        )

    def _as(self, profile):
        c = APIClient()
        c.force_authenticate(user=profile.user)
        return c

    def _chef(self):
        return self._as(self.chef)

    def _plan(self, kitchen=None, name='Weekly Thali'):
        return MealPlan.objects.create(
            kitchen=kitchen or self.kitchen,
            name=name,
            description='test plan',
            is_active=True,
        )

    def _subscribe(self, plan, customer):
        address = Address.objects.create(
            user=customer, address_line1='1 Test Street',
            city='Bengaluru', state='Karnataka', pincode='560001',
        )
        return Subscription.objects.create(
            customer=customer, kitchen=plan.kitchen, plan=plan,
            cadence='week', address=address,
            start_date=date.today() + timedelta(days=7),
            end_date=date.today() + timedelta(days=60),
            status='active', price_paid=Decimal('250'),
        )


class ChefPlanCrudTests(ChefPlanTestBase):

    def test_list_returns_only_own_plans(self):
        mine = self._plan(self.kitchen, 'Mine')
        theirs = self._plan(self.other_kitchen, 'Theirs')
        response = self._chef().get(reverse('chef-meal-plans'))
        self.assertEqual(response.status_code, 200, response.content)
        body = response.json()
        self.assertEqual(body['count'], 1)
        ids = [row['id'] for row in body['results']]
        self.assertIn(mine.id, ids)
        self.assertNotIn(theirs.id, ids)

    def test_list_is_paginated(self):
        for i in range(3):
            self._plan(name=f'Plan {i}')
        response = self._chef().get(reverse('chef-meal-plans'),
                                    {'page_size': 2})
        body = response.json()
        self.assertEqual(body['count'], 3)
        self.assertEqual(len(body['results']), 2)
        self.assertTrue(body['has_next'])

    def test_list_rejects_bad_pagination(self):
        response = self._chef().get(reverse('chef-meal-plans'),
                                    {'page': 'abc'})
        self.assertEqual(response.status_code, 400)

    def test_create_defaults_to_draft_even_if_client_asks_active(self):
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {
                'kitchen': self.kitchen.id,
                'name': 'New plan',
                'description': 'x',
                'is_active': True,          # must be overridden
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertFalse(response.json()['is_active'])
        self.assertFalse(MealPlan.objects.get(id=response.json()['id']).is_active)

    def test_cannot_create_under_another_kitchen(self):
        # The id is a real kitchen, just not this chef's. Accepting it would let
        # any chef attach a plan to a competitor's kitchen.
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {'kitchen': self.other_kitchen.id, 'name': 'Trojan', 'description': ''},
            format='json',
        )
        self.assertEqual(response.status_code, 400, response.content)
        self.assertFalse(
            MealPlan.objects.filter(kitchen=self.other_kitchen).exists()
        )

    def test_create_with_unknown_kitchen_is_400(self):
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {'kitchen': 999999, 'name': 'Ghost', 'description': ''},
            format='json',
        )
        self.assertEqual(response.status_code, 400)

    def test_read_own_plan(self):
        plan = self._plan()
        response = self._chef().get(
            reverse('chef-meal-plan-detail', args=[plan.id])
        )
        self.assertEqual(response.status_code, 200)

    def test_cannot_read_another_chefs_plan(self):
        plan = self._plan(self.other_kitchen)
        response = self._chef().get(
            reverse('chef-meal-plan-detail', args=[plan.id])
        )
        # 404 not 403: a 403 would confirm the plan exists.
        self.assertEqual(response.status_code, 404)

    def test_cannot_update_another_chefs_plan(self):
        plan = self._plan(self.other_kitchen)
        original = plan.name
        response = self._chef().patch(
            reverse('chef-meal-plan-detail', args=[plan.id]),
            {'name': 'Hijacked'},
            format='json',
        )
        self.assertEqual(response.status_code, 404)
        plan.refresh_from_db()
        self.assertEqual(plan.name, original)

    def test_cannot_delete_another_chefs_plan(self):
        plan = self._plan(self.other_kitchen)
        response = self._chef().delete(
            reverse('chef-meal-plan-detail', args=[plan.id])
        )
        self.assertEqual(response.status_code, 404)
        self.assertTrue(MealPlan.objects.filter(pk=plan.pk).exists())

    def test_update_own_plan(self):
        plan = self._plan()
        response = self._chef().patch(
            reverse('chef-meal-plan-detail', args=[plan.id]),
            {'name': 'Renamed', 'description': 'new copy'},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.content)
        plan.refresh_from_db()
        self.assertEqual(plan.name, 'Renamed')

    def test_publish_then_unpublish(self):
        plan = self._plan()
        url = reverse('chef-meal-plan-detail', args=[plan.id])

        self.assertEqual(
            self._chef().patch(url, {'is_active': False}, format='json').status_code,
            200,
        )
        plan.refresh_from_db()
        self.assertFalse(plan.is_active)

        self.assertEqual(
            self._chef().patch(url, {'is_active': True}, format='json').status_code,
            200,
        )
        plan.refresh_from_db()
        self.assertTrue(plan.is_active)

    def test_kitchen_cannot_be_reassigned_via_patch(self):
        # Moving a plan would silently transfer its subscribers.
        plan = self._plan(self.kitchen)
        self._chef().patch(
            reverse('chef-meal-plan-detail', args=[plan.id]),
            {'kitchen': self.other_kitchen.id},
            format='json',
        )
        plan.refresh_from_db()
        self.assertEqual(plan.kitchen_id, self.kitchen.id)

    def test_delete_own_plan(self):
        plan = self._plan()
        response = self._chef().delete(
            reverse('chef-meal-plan-detail', args=[plan.id])
        )
        self.assertEqual(response.status_code, 204)
        self.assertFalse(MealPlan.objects.filter(pk=plan.pk).exists())

    def test_anonymous_is_rejected(self):
        anon = APIClient()
        self.assertIn(
            anon.get(reverse('chef-meal-plans')).status_code, (401, 403),
        )


class ChefPlanRoleTests(ChefPlanTestBase):

    def test_customer_gets_403(self):
        response = self._as(self.customer).get(reverse('chef-meal-plans'))
        self.assertEqual(response.status_code, 403, response.content)

    def test_customer_cannot_create(self):
        response = self._as(self.customer).post(
            reverse('chef-meal-plans'),
            {'kitchen': self.kitchen.id, 'name': 'nope', 'description': ''},
            format='json',
        )
        self.assertEqual(response.status_code, 403)

    def test_chef_without_kitchen_gets_403_not_empty_list(self):
        # Distinguishing "not allowed" from "nothing here" matters: a silent
        # empty list would hide the authorisation problem.
        kitchenless = _mkuser('chef-no-kitchen@p.dev', 'chef')
        response = self._as(kitchenless).get(reverse('chef-meal-plans'))
        self.assertEqual(response.status_code, 403)


class ChefPlanPriceAndSlotTests(ChefPlanTestBase):

    def test_prices_written_in_the_payload(self):
        # Matches PlanPrice.toWriteJson() on the client.
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {
                'kitchen': self.kitchen.id,
                'name': 'Priced plan',
                'description': '',
                'prices': [
                    {'cadence': 'week', 'price': '250', 'is_active': True},
                    {'cadence': 'month', 'price': '900', 'is_active': True},
                ],
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        plan = MealPlan.objects.get(pk=response.json()['id'])
        self.assertEqual(plan.prices.count(), 2)
        self.assertEqual(
            plan.prices.get(cadence='week').price, Decimal('250'),
        )

    def test_unknown_cadence_is_rejected_with_a_clear_message(self):
        # Better than silently dropping the price: the chef is told their
        # payload is wrong. `PlanPriceSerializer` validates `cadence` before
        # `MealPlanWriteSerializer._replace_prices` ever sees the row — that
        # ignore-unknown-cadence branch is a defensive backstop for direct
        # model-level writes, not the API path.
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {
                'kitchen': self.kitchen.id,
                'name': 'Odd plan',
                'description': '',
                'prices': [
                    {'cadence': 'fortnight', 'price': '400', 'is_active': True},
                ],
            },
            format='json',
        )
        self.assertEqual(response.status_code, 400, response.content)
        self.assertIn('prices', response.json())
        # The plan was not created, so no half-built row is left behind.
        self.assertFalse(MealPlan.objects.filter(name='Odd plan').exists())

    def test_a_bad_price_rejects_the_whole_payload_atomically(self):
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {
                'kitchen': self.kitchen.id,
                'name': 'Mixed plan',
                'description': '',
                'prices': [
                    {'cadence': 'week', 'price': '250', 'is_active': True},
                    {'cadence': 'fortnight', 'price': '400', 'is_active': True},
                ],
            },
            format='json',
        )
        self.assertEqual(response.status_code, 400, response.content)
        plan = MealPlan.objects.filter(name='Mixed plan').first()
        self.assertIsNone(plan, 'a rejected payload must not create a plan')

    def test_slots_written_in_the_payload(self):
        # Matches MealPlanSlot.toWriteJson(): day_of_week, meal_type, title,
        # items, is_active.
        response = self._chef().post(
            reverse('chef-meal-plans'),
            {
                'kitchen': self.kitchen.id,
                'name': 'Slotted plan',
                'description': '',
                'slots': [
                    {
                        'day_of_week': 0,
                        'meal_type': 'dinner',
                        'title': 'Monday dinner',
                        'items': [{'name': 'Dal', 'qty': 1, 'price': '0'}],
                        'is_active': True,
                    },
                ],
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        plan = MealPlan.objects.get(pk=response.json()['id'])
        self.assertEqual(plan.slots.count(), 1)
        self.assertEqual(plan.slots.first().title, 'Monday dinner')

    def test_cadence_vocabulary_endpoint(self):
        response = self._chef().get(reverse('plan-cadences'))
        self.assertEqual(response.status_code, 200)
        values = {c['value'] for c in response.json()['cadences']}
        self.assertEqual(values, {'week', 'month', 'year'})
        week = next(c for c in response.json()['cadences'] if c['value'] == 'week')
        self.assertEqual(week['duration_days'], 7)


class ChefSubscriberTests(ChefPlanTestBase):

    def test_plan_subscribers_scoped_to_own_plan(self):
        mine = self._plan(self.kitchen, 'Mine')
        self._subscribe(mine, self.customer)

        response = self._chef().get(
            reverse('chef-plan-subscribers', args=[mine.id])
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['count'], 1)
        self.assertEqual(
            response.json()['results'][0]['customer_uid'], self.customer.uid,
        )

    def test_cannot_list_subscribers_of_another_chefs_plan(self):
        theirs = self._plan(self.other_kitchen)
        self._subscribe(theirs, self.customer)
        response = self._chef().get(
            reverse('chef-plan-subscribers', args=[theirs.id])
        )
        self.assertEqual(response.status_code, 404)

    def test_all_subscribers_across_own_plans(self):
        p1 = self._plan(self.kitchen, 'One')
        p2 = self._plan(self.kitchen, 'Two')
        self._subscribe(p1, self.customer)
        self._subscribe(p2, self.customer)
        self._subscribe(self._plan(self.other_kitchen), self.customer)

        response = self._chef().get(reverse('chef-subscribers'))
        self.assertEqual(response.status_code, 200)
        # Only the two plans belonging to this chef.
        self.assertEqual(response.json()['count'], 2)

    def test_pagination(self):
        plan = self._plan(self.kitchen, 'Paged')
        for i in range(5):
            self._subscribe(plan, _mkuser(f'cust-{i}@p.dev', 'customer'))

        response = self._chef().get(
            reverse('chef-plan-subscribers', args=[plan.id]),
            {'page': 1, 'page_size': 2},
        )
        body = response.json()
        self.assertEqual(body['count'], 5)
        self.assertEqual(len(body['results']), 2)
        self.assertTrue(body['has_next'])

        response = self._chef().get(
            reverse('chef-plan-subscribers', args=[plan.id]),
            {'page': 3, 'page_size': 2},
        )
        body = response.json()
        self.assertEqual(len(body['results']), 1)
        self.assertFalse(body['has_next'])

    def test_bad_pagination_params_are_400(self):
        plan = self._plan()
        response = self._chef().get(
            reverse('chef-plan-subscribers', args=[plan.id]),
            {'page': 'abc'},
        )
        self.assertEqual(response.status_code, 400)

    def test_delete_plan_with_subscribers_is_409(self):
        plan = self._plan()
        self._subscribe(plan, self.customer)
        response = self._chef().delete(
            reverse('chef-meal-plan-detail', args=[plan.id])
        )
        # Subscription.plan is on_delete=PROTECT; the view turns that into a
        # 409 with a usable message rather than letting it become a 500.
        self.assertEqual(response.status_code, 409, response.content)
        self.assertIn('subscriber_count', response.json())


class ChefPlanRoutingTests(ChefPlanTestBase):
    """Guards the /api/auth/ prefix trap that has already bitten this project."""

    def test_endpoints_live_under_api_auth(self):
        # Unauthenticated -> 401 means "route exists"; 404 would mean "no route".
        self.assertEqual(
            APIClient().get('/api/auth/subscriptions/chef-plans/').status_code,
            401,
        )

    def test_bare_api_prefix_does_not_resolve(self):
        self.assertEqual(
            APIClient().get('/api/subscriptions/chef-plans/').status_code, 404,
        )