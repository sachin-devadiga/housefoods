import json
import logging
import os
import re

import requests as http_requests

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .ai_tools import execute_tool

logger = logging.getLogger(__name__)

GEMINI_CHAT_MODEL = 'gemini-2.5-flash'
GEMINI_CHAT_MODELS = ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-3.5-flash-lite', 'gemini-3.6-flash']

SYSTEM_PROMPT = """You are MEAL AI, the in-app assistant for MEALIN — a food ordering app (like Zomato/Swiggy).

ABOUT MEALIN APP:
- Users can browse kitchens (restaurants), view menus, add items to cart, and place orders
- Orders can be paid via Cash on Delivery (COD) or Online payment
- Users can track order status and delivery partner location in real-time
- Users can rate kitchens, add favorites, view order history
- Delivery partners can see assigned deliveries and update status
- Kitchens (chefs) can manage their menu, daily fulfillment, and view orders
- The app supports vegetarian/non-vegetarian filters
- Prices are in Indian Rupees (₹)

YOUR CAPABILITIES — YOU MUST USE TOOLS:
1. SEARCH FOOD: When user asks about ANY food — "what to eat", "biryani", "pizza near me", "best dosa", "cheap food", "veg options", "non-veg", "order from restaurant X" — call search_food IMMEDIATELY
2. LIST RESTAURANTS: When user asks "which restaurants are available", "what restaurants are open", "show me restaurants" — call list_restaurants
3. VIEW CART: When user asks "what's in my cart", "my order", "cart total" — call get_cart
4. ADD TO CART: When user says "add X to cart", "order X", "I want X", "add item 123" — call add_to_cart
5. REMOVE FROM CART: "remove X", "cancel X" — call remove_from_cart
6. UPDATE QUANTITY: "increase quantity", "2 of X" — call update_cart_item
7. RESTAURANT DETAILS: "tell me about restaurant X", "menu of X" — call get_restaurant_details
8. OFFERS: "any discounts", "coupon code", "offers" — call get_applicable_offers
9. PLACE ORDER: "place order", "checkout", "confirm order", "pay now" — call validate_order then place_order
10. ORDER STATUS: "where is my order", "track order", "order status" — call get_order_status
11. PAYMENT: "pay with COD", "cash on delivery", "online payment" — call set_payment_method

ORDERING FLOW:
When user wants to order:
1. First search for food items (search_food) or show restaurants (list_restaurants)
2. When user picks an item, add it to cart (add_to_cart)
3. Show cart contents (get_cart)
4. When user says "place order" or "checkout" — call validate_order first, then place_order
5. Default to COD if user doesn't specify payment method

RULES:
- NEVER say you don't have access to data. You DO — use the tools.
- NEVER make up restaurant names, prices, or menu items. Only use data from tools.
- When user says "what should I eat" — call search_food with a broad query like "popular" or "best" to show real options.
- When user says "order from X" or "something from this restaurant" — call search_food with the restaurant name as filter.
- When showing results, format them nicely: item name, price, rating, restaurant, delivery time.
- If search returns no results, say so and suggest trying different keywords.
- Support Hindi, English, and casual language.
- Be conversational but efficient. Help the user order food in as few steps as possible.
- For COD orders, confirm the order details before placing.
- Always show prices with ₹ symbol.
- When user gives a number like "1" or "2" after seeing search results, assume they want to add that item to cart (by its position in the results list)."""

# Food-related keywords to detect when we should force search_food
_FOOD_KEYWORDS = [
    'eat', 'food', 'hungry', 'biryani', 'pizza', 'burger', 'dosa', 'idli',
    'noodles', 'rice', 'curry', 'chicken', 'mutton', 'paneer', 'veg', 'non-veg',
    'thali', 'butter chicken', 'tikka', 'samosa', 'momos', 'shawarma', 'wrap',
    'sandwich', 'pasta', 'fried rice', 'manchurian', 'dal', 'roti', 'naan',
    'paratha', 'chole', 'pav bhaji', 'vada pav', 'bhel', 'chaat', 'juice',
    'shake', 'coffee', 'tea', 'snacks', 'breakfast', 'lunch', 'dinner', 'meal',
    'dish', 'cuisine', 'recommend', 'suggest', 'kya khana', 'kya khau',
    'bhookh', 'khana', 'dhaba',
]

# Restaurant listing keywords — these should call list_restaurants, NOT search_food
_RESTAURANT_KEYWORDS = [
    'restaurant.*available', 'restaurant.*open', 'which restaurant', 'what restaurant',
    'restaurants near', 'show.*restaurant', 'list.*restaurant',
    'kitchen.*available', 'kitchen.*open', 'which kitchen', 'what kitchen',
    'open now', 'available now', 'named.*as', 'named',
    'check.*restaurant', 'check.*kitchen',
]

# Detect restaurant listing queries
_RESTAURANT_QUERY_RE = re.compile('|'.join(_RESTAURANT_KEYWORDS), re.IGNORECASE)

# Detect "order me X" / "I want X" food queries
_ORDER_KEYWORDS = [
    'order', 'want', 'get me', 'find me', 'search', 'look for',
    'what should i', 'something', 'craving',
]


def _is_food_query(message):
    """Detect if a message is food-related and should trigger search_food."""
    msg_lower = message.lower().strip()

    # If it's a pure restaurant listing query (no order/food intent), return False
    if _RESTAURANT_QUERY_RE.search(msg_lower):
        # But if there's also food intent ("order from restaurant X"), treat as food query
        has_food_intent = any(re.search(kw, msg_lower) for kw in _ORDER_KEYWORDS)
        if not has_food_intent:
            return False

    for kw in _FOOD_KEYWORDS:
        if re.search(kw, msg_lower):
            return True
    return False


def _is_restaurant_query(message):
    """Detect if a message is asking about available restaurants."""
    msg_lower = message.lower().strip()
    return bool(_RESTAURANT_QUERY_RE.search(msg_lower))

_TOOL_DECLARATIONS = [
    {
        'name': 'search_food',
        'description': 'Search for food items across restaurants. Use this for ANY food-related query including "what should I eat", specific dish names, cuisine types, price filters, etc.',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'food': {'type': 'STRING', 'description': 'Food item, cuisine, or search term (e.g. "biryani", "pizza", "best rated", "cheap meals")'},
                'max_price': {'type': 'NUMBER', 'description': 'Maximum price filter in ₹'},
                'sort_preference': {'type': 'STRING', 'enum': ['best_value', 'cheapest', 'fastest', 'best_rated'], 'description': 'How to sort results'},
                'is_veg': {'type': 'BOOLEAN', 'description': 'Filter for vegetarian only'},
                'restaurant': {'type': 'STRING', 'description': 'Filter by restaurant/kitchen name'},
            },
            'required': ['food'],
        },
    },
    {
        'name': 'list_restaurants',
        'description': 'List all currently open and available restaurants/kitchens. Use when user asks "which restaurants are available", "what restaurants are open", "show me restaurants", etc. Also use when user mentions a specific restaurant name to check if it exists.',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'name': {'type': 'STRING', 'description': 'Filter by restaurant name (partial match)'},
                'max_price': {'type': 'NUMBER', 'description': 'Filter by max price in ₹'},
                'is_veg': {'type': 'BOOLEAN', 'description': 'Filter for pure veg restaurants only'},
                'sort_by': {'type': 'STRING', 'enum': ['rating', 'distance', 'fastest'], 'description': 'Sort restaurants by'},
            },
        },
    },
    {
        'name': 'get_cart',
        'description': 'Get the user\'s current cart contents with items, quantities, and total',
        'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
        'name': 'add_to_cart',
        'description': 'Add a menu item to the cart. Use the item_id from search_food results.',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Menu item ID from search results'},
                'quantity': {'type': 'INTEGER', 'description': 'Quantity (default 1)'},
                'special_instructions': {'type': 'STRING', 'description': 'Any special requests'},
            },
            'required': ['item_id'],
        },
    },
    {
        'name': 'update_cart_item',
        'description': 'Update quantity of an item in the cart',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Menu item ID'},
                'quantity': {'type': 'INTEGER', 'description': 'New quantity'},
            },
            'required': ['item_id', 'quantity'],
        },
    },
    {
        'name': 'remove_from_cart',
        'description': 'Remove an item from the cart',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Menu item ID to remove'},
            },
            'required': ['item_id'],
        },
    },
    {
        'name': 'clear_cart',
        'description': 'Clear all items from the cart',
        'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
        'name': 'get_restaurant_details',
        'description': 'Get detailed restaurant/kitchen info including full menu',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'restaurant_id': {'type': 'INTEGER', 'description': 'Restaurant/kitchen ID'},
            },
            'required': ['restaurant_id'],
        },
    },
    {
        'name': 'get_menu_item_details',
        'description': 'Get details for a specific menu item',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Menu item ID'},
            },
            'required': ['item_id'],
        },
    },
    {
        'name': 'get_applicable_offers',
        'description': 'Get available coupons/discounts for an order value',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'order_value': {'type': 'NUMBER', 'description': 'Current order value in ₹'},
            },
            'required': ['order_value'],
        },
    },
    {
        'name': 'validate_order',
        'description': 'Validate the cart is ready for checkout',
        'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
        'name': 'get_order_status',
        'description': 'Get status and tracking info for an order',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'order_id': {'type': 'INTEGER', 'description': 'Order ID'},
            },
            'required': ['order_id'],
        },
    },
    {
        'name': 'set_payment_method',
        'description': 'Set payment method for the order (COD or online)',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'method': {'type': 'STRING', 'enum': ['cod', 'online', 'wallet'], 'description': 'Payment method: cod=cash on delivery, online=digital payment'},
            },
            'required': ['method'],
        },
    },
    {
        'name': 'place_order',
        'description': 'Place an order from the cart. Validates everything and creates the order.',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'payment_method': {'type': 'STRING', 'enum': ['cod', 'online'], 'description': 'cod for cash on delivery, online for digital payment'},
                'address_id': {'type': 'INTEGER', 'description': 'Delivery address ID (optional, uses default)'},
                'special_instructions': {'type': 'STRING', 'description': 'Special instructions for the order'},
            },
            'required': ['payment_method'],
        },
    },
]


def _detect_search_term(message):
    """Extract a food search term from a natural language message."""
    msg = message.lower().strip()
    # Remove common filler words
    fillers = [
        'find me', 'show me', 'search for', 'look for', 'i want', 'i need',
        'get me', 'can you find', 'can i get', 'do you have', 'any',
        'what about', 'how about', 'something like', 'something with',
        'order', 'eat', 'food', 'please', '?', '.', '!', 'hey', 'hi',
        'what should i', 'i want to', 'let me', 'tell me about',
        'kya hai', 'dikhao', 'chahiye', 'khaiye',
    ]
    cleaned = msg
    for f in fillers:
        cleaned = cleaned.replace(f, ' ')
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned or 'popular'


def _build_gemini_contents(message, conversation_history):
    contents = []

    # System prompt as first user/model turn pair
    contents.append({'role': 'user', 'parts': [{'text': SYSTEM_PROMPT}]})
    contents.append({'role': 'model', 'parts': [{'text': 'Understood. I am MEAL AI, ready to help you order food on MEALIN!'}]})

    # Rolling context: keep last 10 turns
    history = (conversation_history or [])[-10:]

    for turn in history:
        role = turn.get('role', 'user')
        text = turn.get('content', '')
        if not text:
            continue
        gemini_role = 'model' if role == 'model' else 'user'
        contents.append({'role': gemini_role, 'parts': [{'text': text}]})

    contents.append({'role': 'user', 'parts': [{'text': message}]})
    return contents


def _call_gemini(contents, tool_config=None):
    api_key = os.environ.get('GEMINI_API_KEY', '')
    if not api_key:
        return None, 'Gemini API not configured'

    last_error = None
    for model_name in GEMINI_CHAT_MODELS:
        url = f'https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent'
        payload = {
            'contents': contents,
            'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 2048,
            },
            'tools': [{'functionDeclarations': _TOOL_DECLARATIONS}],
        }
        if tool_config:
            payload['toolConfig'] = tool_config

        try:
            resp = http_requests.post(
                url,
                params={'key': api_key},
                headers={'Content-Type': 'application/json'},
                json=payload,
                timeout=60,
            )
            if resp.status_code == 200:
                return resp.json(), None
            last_error = f'Gemini API error ({resp.status_code}) on {model_name}: {resp.text[:200]}'
            logger.warning('Gemini %s returned %d: %s', model_name, resp.status_code, resp.text[:500])
        except http_requests.exceptions.Timeout:
            last_error = f'Gemini API timed out on {model_name}'
            logger.warning('Gemini %s timed out', model_name)
        except Exception:
            last_error = f'Gemini service unavailable ({model_name})'
            logger.exception('Gemini %s request failed', model_name)

    return None, last_error or 'Gemini service unavailable'


def _parse_gemini_response(data):
    candidates = data.get('candidates', [])
    if not candidates:
        return '', []

    parts = candidates[0].get('content', {}).get('parts', [])
    response_text = ''
    tool_calls = []

    for part in parts:
        if part.get('thought'):
            continue
        if 'text' in part:
            response_text = part['text']
        elif 'functionCall' in part:
            fc = part['functionCall']
            tool_calls.append({
                'name': fc.get('name', ''),
                'parameters': fc.get('args', {}),
            })

    return response_text, tool_calls


def _execute_tool_calls(tool_calls, user_profile):
    results = []
    for tc in tool_calls:
        name = tc.get('name', '')
        params = tc.get('parameters', {})
        logger.info('[MEAL-AI] Tool call: %s params=%s', name, json.dumps(params, default=str)[:200])
        result = execute_tool(name, params, user_profile)
        logger.info('[MEAL-AI] Tool result: %s → %s', name, json.dumps(result, default=str)[:300])
        if name == 'set_payment_method' and 'method' in result:
            result['payment_method_stored'] = True
        results.append({
            'tool_name': name,
            'parameters': params,
            'result': result,
        })
    return results


def _build_results_context(tool_results):
    """Build context from tool results for Gemini's second pass."""
    lines = []
    for tr in tool_results:
        result_str = json.dumps(tr['result'], default=str)
        if len(result_str) > 4000:
            result_str = result_str[:4000] + '...(truncated)'
        lines.append(f"[Tool: {tr['tool_name']}]\n{result_str}")
    return '\n\n'.join(lines)


def _force_search_food(message, user_profile):
    """Force-call search_food when Gemini didn't call it but should have."""
    search_term = _detect_search_term(message)

    # Try to extract restaurant name from message
    restaurant = None
    restaurant_match = re.search(
        r'(?:from|at|in|near)\s+(?:the\s+)?(?:restaurant\s+)?(\w+)',
        message, re.IGNORECASE
    )
    if restaurant_match:
        restaurant = restaurant_match.group(1)

    params = {'food': search_term}
    if restaurant:
        params['restaurant'] = restaurant

    logger.info('[MEAL-AI] Force search_food with params: %s', params)
    result = execute_tool('search_food', params, user_profile)
    return [{
        'tool_name': 'search_food',
        'parameters': params,
        'result': result,
    }]


class MealAIChatView(APIView):
    """AI chat endpoint that uses Gemini function calling with MEALIN tools."""

    permission_classes = [IsAuthenticated]
    throttle_scope = 'voice'

    def post(self, request):
        message = request.data.get('message', '').strip()
        conversation_history = request.data.get('conversation_history', [])
        location = request.data.get('location', {})

        if not message:
            return Response({'error': 'message is required'}, status=status.HTTP_400_BAD_REQUEST)

        if not isinstance(conversation_history, list) or len(conversation_history) > 30:
            return Response({'error': 'Invalid conversation_history'}, status=status.HTTP_400_BAD_REQUEST)

        user_profile = request.user.profile

        # Update location if provided
        if location:
            lat = location.get('latitude')
            lng = location.get('longitude')
            if lat is not None and lng is not None:
                try:
                    user_profile.current_latitude = float(lat)
                    user_profile.current_longitude = float(lng)
                    user_profile.save(update_fields=['current_latitude', 'current_longitude'])
                except (TypeError, ValueError):
                    pass

        logger.info('[MEAL-AI] User=%s message="%s"', request.user.pk, message[:100])

        # First Gemini call
        contents = _build_gemini_contents(message, conversation_history)
        data, err = _call_gemini(contents)
        if err:
            logger.error('[MEAL-AI] Gemini error: %s', err)
            return Response({'error': err}, status=status.HTTP_502_BAD_GATEWAY)

        response_text, tool_calls = _parse_gemini_response(data)
        logger.info('[MEAL-AI] Gemini pass1: text="%s" tools=%s', response_text[:150], [tc['name'] for tc in tool_calls])

        # Execute tools from Gemini's response
        tool_results = _execute_tool_calls(tool_calls, user_profile) if tool_calls else []

        # FORCE tool calls if Gemini didn't call them but should have
        if not tool_results:
            if _is_restaurant_query(message):
                # Try to extract restaurant name from message
                name_match = re.search(r'(?:named|called|named as)\s+(\w+)', message, re.IGNORECASE)
                params = {}
                if name_match:
                    params['name'] = name_match.group(1)
                logger.info('[MEAL-AI] Gemini did not call tools for restaurant query — forcing list_restaurants params=%s', params)
                result = execute_tool('list_restaurants', params, user_profile)
                tool_results = [{
                    'tool_name': 'list_restaurants',
                    'parameters': params,
                    'result': result,
                }]
            elif _is_food_query(message):
                logger.info('[MEAL-AI] Gemini did not call tools for food query — forcing search_food')
                tool_results = _force_search_food(message, user_profile)

        # If tools were called, do a second Gemini pass with the results
        if tool_results:
            results_ctx = _build_results_context(tool_results)
            followup = (
                f"Tool execution results:\n{results_ctx}\n\n"
                "Present these results to the user in a friendly way. "
                "Use the actual data — item names, prices in ₹, ratings, restaurant names, delivery times. "
                "Format results as a clean list. Do NOT make up values. "
                "If results are empty, tell the user no matches were found and suggest they try different keywords."
            )

            model_text = response_text or 'Let me look that up for you.'
            contents.append({'role': 'model', 'parts': [{'text': model_text}]})
            contents.append({'role': 'user', 'parts': [{'text': followup}]})

            data2, err2 = _call_gemini(contents)
            if not err2:
                response_text2, _ = _parse_gemini_response(data2)
                if response_text2:
                    response_text = response_text2

        # Fallback: if still no response, provide a default
        if not response_text:
            if tool_results:
                response_text = "Here are the results I found!"
            else:
                response_text = "I'm here to help you order food on MEALIN! Try asking me to search for a dish, check your cart, or place an order."

        # Build enriched results for frontend card rendering
        enriched_results = []
        for tr in tool_results:
            enriched_results.append({
                'tool_name': tr['tool_name'],
                'parameters': tr['parameters'],
                'result': tr['result'],
            })

        return Response({
            'response_text': response_text,
            'tool_calls': [{'name': tc['name'], 'parameters': tc['parameters']} for tc in tool_calls],
            'tool_results': enriched_results,
        })
