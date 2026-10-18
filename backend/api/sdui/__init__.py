"""Server-Driven UI (SDUI) backend.

Screens are stored as JSON "specs" (a tree of nodes) and rendered by the
Flutter client. This package owns the storage, the schema that guarantees a
spec is renderable, the public read API, and the admin CMS used to author
specs.

Contract summary (a parallel Dart client codes against this exact shape):

    {
      "key": "customer_home",
      "version": 3,
      "schema_version": 1,
      "root": {"type": "column", "children": [...]}
    }

Read endpoints live under /api/auth/config/ because api.urls is included at
'api/auth/' (see backend/urls.py).
"""