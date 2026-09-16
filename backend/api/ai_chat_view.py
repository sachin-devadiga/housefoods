import json
import logging
import os

import requests as http_requests

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .ai_tools import execute_tool

logger = logging.getLogger(__name__)

GEMINI_CHAT_MODEL = 'gemini-2.5-flash'

SYSTEM_PROMPT = """You are MEAL AI, the intelligent food-ordering assistant inside MEALIN.
You help users discover restaurants, browse menus, manage their cart, apply offers, and place orders.

RULES:
- You MUST use the provided tools to fetch real data. Never invent restaurant names, prices, ratings, or menu items.
- If a user asks something unrelated to food ordering, politely redirect them.
- Support conversational context and follow-up questions.
- Ask clarifying questions when the user's request is ambiguous.
- You may support multiple languages (English, Hindi, Kannada, etc.) — reply in the language the user uses.
- Keep responses concise and conversational.
- When adding to cart, confirm with the user before placing the order.
- Always show prices in ₹ (Indian Rupees).

TOOL USAGE:
- Use search_food when the user wants to find food items.
- Use get_cart to show the user their current cart.
- Use add_to_cart when the user wants to add an item.
- Use update_cart_item to change quantity.
- Use remove_from_cart to remove an item.
- Use clear_cart to empty the cart.
- Use get_restaurant_details for restaurant info.
- Use get_menu_item_details for specific item info.
- Use get_applicable_offers when the user asks about discounts or coupons.
- Use validate_order before confirming an order.
- Use get_order_status to check an order.
- Use set_payment_method to record payment preference.
- Use place_order to place an order from the user's cart.

Respond in valid JSON:
{
  "response": "your conversational reply",
  "tool_calls": [{"name": "tool_name", "parameters": {...}}, ...]
}
If no tool is needed, return tool_calls as an empty list."""


TOOL_DECLARATIONS = [
    {
        'name': 'search_food',
        'description': 'Search for food items across restaurants',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'food': {'type': 'STRING', 'description': 'Food item to search for'},
                'max_price': {'type': 'NUMBER', 'description': 'Maximum price filter'},
                'sort_preference': {'type': 'STRING', 'enum': ['best_value', 'cheapest', 'fastest', 'best_rated'], 'description': 'Sort preference'},
                'is_veg': {'type': 'BOOLEAN', 'description': 'Filter for vegetarian only'},
                'restaurant': {'type': 'STRING', 'description': 'Filter by restaurant name'},
            },
            'required': ['food'],
        },
    },
    {
        'name': 'get_cart',
        'description': 'Get the user\'s current cart contents',
        'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
        'name': 'add_to_cart',
        'description': 'Add a menu item to the cart',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Menu item ID'},
                'quantity': {'type': 'INTEGER', 'description': 'Quantity (default 1)'},
                'special_instructions': {'type': 'STRING', 'description': 'Special instructions'},
            },
            'required': ['item_id'],
        },
    },
    {
        'name': 'update_cart_item',
        'description': 'Update quantity of a cart item',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'item_id': {'type': 'INTEGER', 'description': 'Cart item ID'},
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
                'item_id': {'type': 'INTEGER', 'description': 'Cart item ID'},
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
        'description': 'Get detailed restaurant info including full menu',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'restaurant_id': {'type': 'INTEGER', 'description': 'Restaurant ID'},
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
        'description': 'Get coupons/discounts applicable to an order value',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'order_value': {'type': 'NUMBER', 'description': 'Current order value'},
            },
            'required': ['order_value'],
        },
    },
    {
        'name': 'validate_order',
        'description': 'Validate the cart is ready for order placement',
        'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
        'name': 'get_order_status',
        'description': 'Get status of an existing order',
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
        'description': 'Record payment method preference',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'method': {'type': 'STRING', 'enum': ['cod', 'online', 'wallet'], 'description': 'Payment method'},
            },
            'required': ['method'],
        },
    },
    {
        'name': 'place_order',
        'description': 'Place an order from the user\'s current cart. Validates cart, kitchen, items, and address before creating the order.',
        'parameters': {
            'type': 'OBJECT',
            'properties': {
                'payment_method': {'type': 'STRING', 'enum': ['cod', 'online'], 'description': 'Payment method: cod for cash on delivery, online for digital payment'},
                'address_id': {'type': 'INTEGER', 'description': 'Delivery address ID (optional, uses default if not provided)'},
                'special_instructions': {'type': 'STRING', 'description': 'Special instructions for the order'},
            },
            'required': ['payment_method'],
        },
    },
]


def _build_gemini_contents(message, conversation_history):
    contents = []

    # System prompt as first user/model turn pair
    contents.append({'role': 'user', 'parts': [{'text': SYSTEM_PROMPT}]})
    contents.append({'role': 'model', 'parts': [{'text': 'Understood. I am MEAL AI, ready to help with food ordering.'}]})

    # Rolling context: keep last 12 turns to stay within token limits
    history = (conversation_history or [])[-12:]

    for turn in history:
        role = turn.get('role', 'user')
        text = turn.get('content', '')
        if not text:
            continue
        gemini_role = 'model' if role == 'model' else 'user'
        contents.append({'role': gemini_role, 'parts': [{'text': text}]})

    contents.append({'role': 'user', 'parts': [{'text': message}]})
    return contents


def _call_gemini(contents):
    api_key = os.environ.get('GEMINI_API_KEY', '')
    if not api_key:
        return None, 'Gemini API not configured'

    url = f'https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_CHAT_MODEL}:generateContent'
    payload = {
        'contents': contents,
        'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
            'thinkingConfig': {'thinkingBudget': 0},
        },
        'tools': [{'functionDeclarations': TOOL_DECLARATIONS}],
    }

    try:
        resp = http_requests.post(
            url,
            headers={'x-goog-api-key': api_key},
            json=payload,
            timeout=60,
        )
        if resp.status_code != 200:
            logger.error('Gemini chat error: %d %s', resp.status_code, resp.text[:500])
            return None, f'Gemini API error ({resp.status_code})'
        return resp.json(), None
    except http_requests.exceptions.Timeout:
        logger.error('Gemini chat request timed out')
        return None, 'Gemini API timed out'
    except Exception:
        logger.exception('Gemini chat request failed')
        return None, 'Gemini service unavailable'


def _parse_gemini_response(data):
    candidates = data.get('candidates', [])
    if not candidates:
        return '', []

    parts = candidates[0].get('content', {}).get('parts', [])
    response_text = ''
    tool_calls = []

    for part in parts:
        # Skip thinking/thought parts (Gemini 2.5 returns these)
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
        result = execute_tool(name, params, user_profile)
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
        # Truncate very large results to stay within token limits
        if len(result_str) > 2000:
            result_str = result_str[:2000] + '...(truncated)'
        lines.append(f"[Tool: {tr['tool_name']}]\n{result_str}")
    return '\n\n'.join(lines)


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

        # First Gemini call — may request tool calls
        contents = _build_gemini_contents(message, conversation_history)
        data, err = _call_gemini(contents)
        if err:
            return Response({'error': err}, status=status.HTTP_502_BAD_GATEWAY)

        response_text, tool_calls = _parse_gemini_response(data)

        # Execute tools
        tool_results = _execute_tool_calls(tool_calls, user_profile) if tool_calls else []

        # If tools were called, do a second Gemini pass with the results
        if tool_results:
            results_ctx = _build_results_context(tool_results)
            followup_parts = []
            if response_text:
                followup_parts.append(response_text)
            followup_parts.append(f"\n\nTool results:\n{results_ctx}")
            followup_parts.append(
                '\n\nNow respond to the user with the above information. '
                'Use the tool data directly — do not make up values. '
                'If the results show errors, explain them to the user clearly.'
            )

            contents.append({'role': 'model', 'parts': [{'text': response_text or ''}]})
            contents.append({'role': 'user', 'parts': [{'text': ''.join(followup_parts)}]})

            data2, err2 = _call_gemini(contents)
            if not err2:
                response_text2, _ = _parse_gemini_response(data2)
                if response_text2:
                    response_text = response_text2

        # Build tool_results with item details for frontend card rendering
        enriched_results = []
        for tr in tool_results:
            enriched = {
                'tool_name': tr['tool_name'],
                'parameters': tr['parameters'],
                'result': tr['result'],
            }
            enriched_results.append(enriched)

        return Response({
            'response_text': response_text,
            'tool_calls': [{'name': tc['name'], 'parameters': tc['parameters']} for tc in tool_calls],
            'tool_results': enriched_results,
        })
