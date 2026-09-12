#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# init-letsencrypt.sh — One-time SSL certificate initialization
#
# Run this script ONCE on the VPS before starting docker compose.
# It uses Certbot in standalone mode (temporarily binds port 80)
# to obtain the first Let's Encrypt certificate.
#
# Usage:
#   chmod +x init-letsencrypt.sh
#   ./init-letsencrypt.sh
#
# Make sure:
#   - Port 80 is open on the VPS firewall
#   - Your domain's DNS A record points to this VPS IP
#   - Docker is installed
#   - .env file exists with DOMAIN= set
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Load domain from .env ────────────────────────────────────────
if [ -f .env ]; then
    # shellcheck disable=SC1091
    source .env
else
    echo "❌ Error: .env file not found!"
    echo "   Copy .env.example to .env and set your DOMAIN."
    exit 1
fi

if [ -z "${DOMAIN:-}" ]; then
    echo "❌ Error: DOMAIN variable is not set in .env"
    exit 1
fi

# ── Ask for email ────────────────────────────────────────────────
read -rp "📧 Enter your email for Let's Encrypt notifications: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "❌ Error: Email is required."
    exit 1
fi

echo ""
echo "🚀 Initializing Let's Encrypt certificate for: ${DOMAIN}"
echo "   Email: ${EMAIL}"
echo ""

# ── Create required directories ──────────────────────────────────
mkdir -p ./certbot/conf ./certbot/www

# ── Stop any services using port 80 ─────────────────────────────
echo "⏹  Stopping any running containers that might use port 80..."
docker compose down 2>/dev/null || true

# ── Obtain certificate (standalone mode) ────────────────────────
echo "🔐 Obtaining SSL certificate from Let's Encrypt..."
echo "   (Certbot will temporarily use port 80)"
echo ""

docker run --rm \
    -p "80:80" \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    certbot/certbot certonly \
        --standalone \
        --email "${EMAIL}" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "${DOMAIN}"

echo ""
echo "✅ Certificate obtained successfully!"
echo ""
echo "🚀 Starting the full stack..."
docker compose up -d

echo ""
echo "════════════════════════════════════════════════════"
echo "  🪐 Planeta Bzzzt! is now live!"
echo "  🌐 https://${DOMAIN}"
echo "════════════════════════════════════════════════════"
echo ""
echo "📝 Next steps:"
echo "   1. Export Godot 2D game → ../web/2d/"
echo "   2. Export Godot 3D game → ../web/3d/"
echo "   3. Restart nginx: docker compose restart web"
