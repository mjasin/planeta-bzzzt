# ═══════════════════════════════════════════════
# Planeta Bzzzt! — Nginx Docker Image
# Build context: project root (planeta-bzzzt/)
# ═══════════════════════════════════════════════

FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx template — Docker's nginx:alpine image automatically runs
# envsubst on *.template files placed in /etc/nginx/templates/
# See: https://hub.docker.com/_/nginx (section "Using environment variables")
COPY docker/nginx/nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy the landing page into the web root
COPY landing/ /usr/share/nginx/html/

# The game files (web/2d/, web/3d/) are mounted as volumes at runtime
# so they don't need to be baked into the image. This allows updating
# game exports without rebuilding the Docker image.

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost/health 2>/dev/null || wget -qO- http://localhost/ 2>/dev/null || exit 1
