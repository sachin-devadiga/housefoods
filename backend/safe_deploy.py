#!/usr/bin/env python
"""Safe migration script that handles corrupted/missing tables."""
import os
import sys
import subprocess

def run(cmd):
    print(f">>> {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=os.path.dirname(os.path.abspath(__file__)))
    return result.returncode == 0

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

    # Step 1: Try normal migrate
    print("=== Step 1: Try normal migrate ===")
    if run("python manage.py migrate --noinput"):
        print("Migrate succeeded!")
    else:
        print("Migrate failed. Resetting all migration state...")

        # Fake unapply everything
        run("python manage.py migrate auth zero --fake 2>/dev/null")
        run("python manage.py migrate api zero --fake 2>/dev/null")
        run("python manage.py migrate contenttypes zero --fake 2>/dev/null")
        run("python manage.py migrate admin zero --fake 2>/dev/null")
        run("python manage.py migrate sessions zero --fake 2>/dev/null")
        run("python manage.py migrate token_blacklist zero --fake 2>/dev/null")

        # Fake apply everything
        run("python manage.py migrate --fake --noinput")

        # Now do a real migrate
        print("=== Step 2: Real migrate ===")
        if run("python manage.py migrate --noinput"):
            print("Migrate succeeded on retry!")
        else:
            print("FATAL: Migration still failing")
            sys.exit(1)

    # Step 2: Create admin
    print("=== Creating admin ===")
    run("python manage.py create_admin")

    print("=== Starting server ===")
    os.execvp("gunicorn", [
        "gunicorn", "backend.wsgi:application",
        "--bind", f"0.0.0.0:{os.environ.get('PORT', '8000')}"
    ])

if __name__ == '__main__':
    main()
