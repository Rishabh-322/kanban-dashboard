# ----------------------------
# Stage 1: Build React app
# ----------------------------
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


# ----------------------------
# Stage 2: Production runtime
# ----------------------------
FROM nginxinc/nginx-unprivileged:alpine

COPY --from=builder --chown=101:101 /app/dist /usr/share/nginx/html
COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf

USER 101

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["nginx", "-g", "daemon off;"]