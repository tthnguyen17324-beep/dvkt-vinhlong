FROM node:24-alpine
ENV NODE_ENV=production DATA_DIR=/app/data PORT=8000
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY server ./server
COPY scripts ./scripts
COPY public ./public
RUN mkdir -p /app/data && chown -R node:node /app
USER node
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1:8000/api/config >/dev/null || exit 1
CMD ["node", "--no-warnings", "server/index.mjs"]
