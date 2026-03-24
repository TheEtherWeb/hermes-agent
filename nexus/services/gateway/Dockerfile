FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD node -e "require('http').get('http://localhost:' + (process.env.PORT||3001) + '/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "dist/index.js"]
