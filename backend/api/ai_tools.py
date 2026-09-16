import math
import logging
from decimal import Decimal

from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from .models import (
    Kitchen, MenuItem, MenuCategory, Cart, CartItem,
    Order, OrderItem, Coupon, Notification, UserProfile, Address,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Haversine helper
# ---------------------------------------------------------------------------

def _haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(d_lon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _estimate_eta(distance_km, preparation_time):
    travel_time = max(distance_km * 5, 0)
    return int(max(preparation_time + travel_time, 15))


def _cart_summary(cart):
    items = []
    for ci in cart.items.select_related('menu_item').all():
        items.append({
            'item_name': ci.menu_item.name,
            'item_id': ci.menu_item.pk,
            'quantity': ci.quantity,
            'price': float(ci.menu_item.price),
            'subtotal': float(ci.menu_item.price * ci.quantity),
        })
    return {
        'kitchen_name': cart.kitchen.name if cart.kitchen else None,
        'items': items,
        'total_items': cart.total_item_count,
        'subtotal': float(cart.subtotal),
    }


# ---------------------------------------------------------------------------
# Individual tool functions
# ---------------------------------------------------------------------------

def search_food(params, user_profile):
    food = params.get('food', '')
    max_price = params.get('max_price')
    sort_pref = params.get('sort_preference', 'best_value')
    is_veg = params.get('is_veg')
    restaurant = params.get('restaurant')

    if not food:
        return {'error': 'food parameter is required'}

    # DB-level filtering for efficiency — only fetch what matches
    base_qs = MenuItem.objects.filter(
        is_available=True,
        kitchen__status='approved',
        kitchen__is_open=True,
    ).select_related('kitchen')

    # Multi-word search: match each word independently for better recall
    words = food.split()
    if words:
        q = Q()
        for w in words:
            q |= Q(name__icontains=w)
        base_qs = base_qs.filter(q)

    if max_price is not None:
        base_qs = base_qs.filter(price__lte=Decimal(str(max_price)))
    if is_veg is not None:
        base_qs = base_qs.filter(is_veg=bool(is_veg))
    if restaurant:
        base_qs = base_qs.filter(kitchen__name__icontains=restaurant)

    user_lat = getattr(user_profile, 'current_latitude', None)
    user_lon = getattr(user_profile, 'current_longitude', None)

    results = []
    # Process all matching items (no arbitrary cutoff)
    for item in base_qs.iterator(chunk_size=200):
        try:
            k_lat = float(item.kitchen.latitude) if item.kitchen.latitude else None
            k_lon = float(item.kitchen.longitude) if item.kitchen.longitude else None
        except (TypeError, ValueError):
            k_lat, k_lon = None, None

        if user_lat and user_lon and k_lat and k_lon:
            dist = _haversine_km(float(user_lat), float(user_lon), k_lat, k_lon)
        else:
            dist = 999.0

        eta = _estimate_eta(dist, item.preparation_time or 20)

        rating_val = 0.0
        if item.kitchen.rating is not None:
            try:
                rating_val = float(item.kitchen.rating)
            except (TypeError, ValueError):
                rating_val = 0.0

        total_ratings_val = 0
        if item.kitchen.total_ratings is not None:
            try:
                total_ratings_val = int(item.kitchen.total_ratings)
            except (TypeError, ValueError):
                total_ratings_val = 0

        price_val = 0.0
        try:
            price_val = float(item.price)
        except (TypeError, ValueError):
            price_val = 0.0

        results.append({
            'item_id': item.pk,
            'item_name': item.name,
            'price': price_val,
            'restaurant_name': item.kitchen.name,
            'restaurant_id': item.kitchen.pk,
            'rating': rating_val,
            'total_ratings': total_ratings_val,
            'distance_km': round(dist, 2),
            'estimated_minutes': eta,
            'is_veg': item.is_veg,
            'image_url': item.image_url or '',
            'description': item.description or '',
        })

    if not results:
        return {'results': [], 'message': 'No matching items found'}

    # Normalise for scoring (guard against zero/empty)
    max_price_val = max((r['price'] for r in results), default=1) or 1
    max_dist = max((r['distance_km'] for r in results), default=1) or 1
    max_eta = max((r['estimated_minutes'] for r in results), default=1) or 1

    def _score(r):
        p_norm = r['price'] / max_price_val
        d_norm = r['distance_km'] / max_dist
        e_norm = r['estimated_minutes'] / max_eta
        return r['rating'] * 0.3 + (1 - p_norm) * 0.3 + (1 - d_norm) * 0.2 + (1 - e_norm) * 0.2

    if sort_pref == 'cheapest':
        results.sort(key=lambda r: r['price'])
    elif sort_pref == 'fastest':
        results.sort(key=lambda r: r['estimated_minutes'])
    elif sort_pref == 'best_rated':
        results.sort(key=lambda r: (-(r['rating']), -(r['total_ratings'])))
    else:
        results.sort(key=_score, reverse=True)

    return {'results': results[:10]}


def get_cart(params, user_profile):
    cart = Cart.objects.filter(user=user_profile).first()
    if not cart:
        return {
            'kitchen_name': None,
            'items': [],
            'total_items': 0,
            'subtotal': 0,
        }
    return _cart_summary(cart)


def add_to_cart(params, user_profile):
    item_id = params.get('item_id')
    quantity = int(params.get('quantity', 1))
    special_instructions = params.get('special_instructions', '')

    if not item_id:
        return {'error': 'item_id is required'}

    try:
        menu_item = MenuItem.objects.select_related('kitchen').get(pk=item_id, is_available=True)
    except MenuItem.DoesNotExist:
        return {'error': 'Menu item not found or unavailable'}

    kitchen = menu_item.kitchen
    if kitchen.status != 'approved':
        return {'error': f'{kitchen.name} is not approved for ordering'}
    if not kitchen.is_open:
        return {'error': f'{kitchen.name} is currently closed'}

    cart = Cart.objects.filter(user=user_profile).first()
    if not cart:
        cart = Cart.objects.create(user=user_profile, kitchen=kitchen)

    if cart.kitchen and cart.kitchen.pk != menu_item.kitchen.pk:
        return {'error': 'Cart has items from a different restaurant. Clear cart first.', 'action_required': 'clear_cart'}

    cart.kitchen = menu_item.kitchen
    cart.save()

    cart_item, created = CartItem.objects.get_or_create(
        cart=cart, menu_item=menu_item,
        defaults={'quantity': quantity, 'special_instructions': special_instructions},
    )
    if not created:
        cart_item.quantity += quantity
        if special_instructions:
            cart_item.special_instructions = special_instructions
        cart_item.save()

    return {'message': f'{quantity}x {menu_item.name} added to cart', 'cart': _cart_summary(cart)}


def update_cart_item(params, user_profile):
    item_id = params.get('item_id')
    quantity = int(params.get('quantity', 1))

    if not item_id:
        return {'error': 'item_id is required'}

    cart = Cart.objects.filter(user=user_profile).first()
    if not cart:
        return {'error': 'Cart is empty'}
    try:
        ci = CartItem.objects.get(pk=item_id, cart=cart)
    except CartItem.DoesNotExist:
        return {'error': 'Cart item not found'}

    if quantity <= 0:
        ci.delete()
        msg = 'Item removed from cart'
    else:
        ci.quantity = quantity
        ci.save()
        msg = f'{ci.menu_item.name} quantity updated to {quantity}'

    if cart.items.count() == 0:
        cart.kitchen = None
        cart.save()

    return {'message': msg, 'cart': _cart_summary(cart)}


def remove_from_cart(params, user_profile):
    item_id = params.get('item_id')
    if not item_id:
        return {'error': 'item_id is required'}

    cart = Cart.objects.filter(user=user_profile).first()
    if not cart:
        return {'error': 'Cart is empty'}
    try:
        ci = CartItem.objects.get(pk=item_id, cart=cart)
        name = ci.menu_item.name
        ci.delete()
    except CartItem.DoesNotExist:
        return {'error': 'Cart item not found'}

    if cart.items.count() == 0:
        cart.kitchen = None
        cart.save()

    return {'message': f'{name} removed from cart', 'cart': _cart_summary(cart)}


def clear_cart(params, user_profile):
    cart = Cart.objects.filter(user=user_profile).first()
    if not cart:
        return {'message': 'Cart already empty'}
    count = cart.items.count()
    cart.items.all().delete()
    cart.kitchen = None
    cart.save()
    return {'message': f'Cart cleared ({count} items removed)'}


def get_restaurant_details(params, user_profile):
    restaurant_id = params.get('restaurant_id')
    if not restaurant_id:
        return {'error': 'restaurant_id is required'}

    try:
        kitchen = Kitchen.objects.get(pk=restaurant_id, status='approved')
    except Kitchen.DoesNotExist:
        return {'error': 'Restaurant not found'}

    categories = MenuCategory.objects.filter(kitchen=kitchen).order_by('sort_order')
    menu = []
    for cat in categories:
        items = MenuItem.objects.filter(kitchen=kitchen, category=cat, is_available=True)
        menu.append({
            'category': cat.name,
            'items': [{
                'item_id': i.pk,
                'name': i.name,
                'price': float(i.price),
                'description': i.description,
                'is_veg': i.is_veg,
                'image_url': i.image_url,
                'preparation_time': i.preparation_time,
            } for i in items],
        })

    user_lat = getattr(user_profile, 'current_latitude', None)
    user_lon = getattr(user_profile, 'current_longitude', None)
    dist = _haversine_km(user_lat or 0, user_lon or 0,
                          kitchen.latitude, kitchen.longitude) if (user_lat and user_lon) else None

    return {
        'restaurant_id': kitchen.pk,
        'name': kitchen.name,
        'rating': kitchen.rating or 0.0,
        'total_ratings': kitchen.total_ratings or 0,
        'is_open': kitchen.is_open,
        'is_veg': kitchen.is_veg,
        'address': kitchen.address,
        'distance_km': round(dist, 2) if dist is not None else None,
        'estimated_delivery_time': _estimate_eta(dist or 5, 20),
        'menu': menu,
    }


def get_menu_item_details(params, user_profile):
    item_id = params.get('item_id')
    if not item_id:
        return {'error': 'item_id is required'}

    try:
        item = MenuItem.objects.select_related('kitchen', 'category').get(pk=item_id)
    except MenuItem.DoesNotExist:
        return {'error': 'Menu item not found'}

    return {
        'item_id': item.pk,
        'name': item.name,
        'price': float(item.price),
        'description': item.description,
        'is_available': item.is_available,
        'is_veg': item.is_veg,
        'preparation_time': item.preparation_time,
        'image_url': item.image_url,
        'restaurant': {
            'restaurant_id': item.kitchen.pk,
            'name': item.kitchen.name,
            'is_open': item.kitchen.is_open,
        },
        'category': item.category.name if item.category else None,
    }


def get_applicable_offers(params, user_profile):
    order_value = float(params.get('order_value', 0))
    now = __import__('django.utils.timezone', fromlist=['now']).now
    coupons = Coupon.objects.filter(
        is_active=True,
        expiry_date__gt=now(),
        min_order_value__lte=Decimal(str(order_value)),
    )
    results = []
    for c in coupons:
        if c.usage_limit > 0 and c.used_count >= c.usage_limit:
            continue
        if c.discount_type == 'flat':
            discount = float(c.discount_value)
        else:
            discount = order_value * float(c.discount_value) / 100
            if c.max_discount:
                discount = min(discount, float(c.max_discount))
        results.append({
            'code': c.code,
            'discount_type': c.discount_type,
            'discount_value': float(c.discount_value),
            'discount_amount': round(discount, 2),
            'min_order_value': float(c.min_order_value),
        })
    return {'offers': results}


def validate_order(params, user_profile):
    errors = []
    cart = Cart.objects.filter(user=user_profile).first()

    if not cart or cart.items.count() == 0:
        errors.append('Cart is empty')
        return {
            'is_valid': False,
            'errors': errors,
            'cart': None,
        }
    if not cart.kitchen:
        errors.append('No restaurant selected')
    elif not cart.kitchen.is_open:
        errors.append(f'{cart.kitchen.name} is currently closed')
    elif cart.kitchen.status != 'approved':
        errors.append(f'{cart.kitchen.name} is not approved')

    unavailable = []
    for ci in cart.items.select_related('menu_item').all():
        if not ci.menu_item.is_available:
            unavailable.append(ci.menu_item.name)
    if unavailable:
        errors.append(f'Unavailable items: {", ".join(unavailable)}')

    return {
        'is_valid': len(errors) == 0,
        'errors': errors,
        'cart': _cart_summary(cart) if not errors else None,
    }


def get_order_status(params, user_profile):
    order_id = params.get('order_id')
    if not order_id:
        return {'error': 'order_id is required'}

    try:
        order = Order.objects.get(pk=order_id, customer=user_profile)
    except Order.DoesNotExist:
        return {'error': 'Order not found'}

    return {
        'order_id': order.pk,
        'status': order.status,
        'delivery_status': order.delivery_status,
        'kitchen_name': order.kitchen.name,
        'amount': float(order.amount),
        'created_at': order.created_at.isoformat(),
    }


def set_payment_method(params, user_profile):
    method = params.get('method', '')
    if method not in ('cod', 'online', 'wallet'):
        return {'error': 'method must be cod, online, or wallet'}
    return {'message': f'Payment preference set to {method}', 'method': method}


def place_order(params, user_profile):
    """Place an order from the user's cart. Mimics PlaceOrderView logic."""
    from .notification_utils import notify_chef_new_order, notify_customer_order_status

    payment_method = params.get('payment_method', 'cod')
    address_id = params.get('address_id')
    special_instructions = params.get('special_instructions', '')

    if payment_method not in ('cod', 'online'):
        return {'error': 'payment_method must be cod or online'}

    cart = Cart.objects.filter(user=user_profile).first()
    if not cart or cart.items.count() == 0:
        return {'error': 'Cart is empty'}
    if not cart.kitchen:
        return {'error': 'No restaurant selected in cart'}

    kitchen = cart.kitchen
    if kitchen.status != 'approved':
        return {'error': f'{kitchen.name} is not approved'}
    if not kitchen.is_open:
        return {'error': f'{kitchen.name} is currently closed'}

    unavailable = []
    for ci in cart.items.select_related('menu_item').all():
        if not ci.menu_item.is_available:
            unavailable.append(ci.menu_item.name)
    if unavailable:
        return {'error': f'Unavailable items: {", ".join(unavailable)}'}

    address = None
    if address_id:
        address = Address.objects.filter(pk=address_id, user=user_profile).first()
        if not address:
            return {'error': 'Address not found'}
    else:
        address = Address.objects.filter(user=user_profile, is_default=True).first()
        if not address:
            address = Address.objects.filter(user=user_profile).first()
    if not address:
        return {'error': 'No delivery address found. Please add an address first.'}

    delivery_address_text = f'{address.address_line1}, {address.address_line2}, {address.landmark}, {address.city}, {address.state} {address.pincode}'.strip(', ')

    subtotal = sum(ci.menu_item.price * ci.quantity for ci in cart.items.select_related('menu_item').all())
    tax = subtotal * Decimal('0.05')
    platform_fee = Decimal('5.00')
    delivery_fee = Decimal('30.00')
    discount = Decimal('0.00')
    total = subtotal + tax + platform_fee + delivery_fee - discount

    with transaction.atomic():
        order = Order.objects.create(
            customer=user_profile,
            kitchen=kitchen,
            order_type='one_time',
            amount=total,
            subtotal=subtotal,
            tax=tax,
            platform_fee=platform_fee,
            delivery_fee=delivery_fee,
            delivery_address=delivery_address_text,
            delivery_latitude=getattr(address, 'latitude', None) or getattr(user_profile, 'current_latitude', None),
            delivery_longitude=getattr(address, 'longitude', None) or getattr(user_profile, 'current_longitude', None),
            status='active',
            delivery_status='pending',
        )

        for ci in cart.items.select_related('menu_item').all():
            OrderItem.objects.create(
                order=order,
                menu_item=ci.menu_item,
                quantity=ci.quantity,
                price_at_order=ci.menu_item.price,
                special_instructions=ci.special_instructions or special_instructions,
            )

        if payment_method == 'cod':
            order.status = 'active'
            order.save()
        else:
            order.status = 'active'
            order.save()

        cart.items.all().delete()
        cart.kitchen = None
        cart.save()

    notify_chef_new_order(kitchen.chef, order)
    notify_customer_order_status(order, 'placed')

    return {
        'order_id': order.pk,
        'status': order.status,
        'restaurant_name': kitchen.name,
        'estimated_delivery_time': 30,
        'total_amount': float(total),
        'payment_method': payment_method,
    }


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

TOOLS = {
    'search_food': search_food,
    'get_cart': get_cart,
    'add_to_cart': add_to_cart,
    'update_cart_item': update_cart_item,
    'remove_from_cart': remove_from_cart,
    'clear_cart': clear_cart,
    'get_restaurant_details': get_restaurant_details,
    'get_menu_item_details': get_menu_item_details,
    'get_applicable_offers': get_applicable_offers,
    'validate_order': validate_order,
    'get_order_status': get_order_status,
    'set_payment_method': set_payment_method,
    'place_order': place_order,
}


def execute_tool(tool_name, parameters, user_profile):
    fn = TOOLS.get(tool_name)
    if fn is None:
        return {'error': f'Unknown tool: {tool_name}'}
    try:
        return fn(parameters, user_profile)
    except Exception:
        logger.exception('Tool %s failed', tool_name)
        return {'error': 'Tool execution failed'}
