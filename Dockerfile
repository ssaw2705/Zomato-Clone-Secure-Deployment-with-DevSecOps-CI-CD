# ---- Build stage ----
# react-scripts 3.x (webpack 4) cần Node 16 để tránh lỗi ERR_OSSL_EVP_UNSUPPORTED
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# ---- Run stage: phục vụ bản build tĩnh ----
FROM node:16-alpine
WORKDIR /app
RUN npm install -g serve
COPY --from=builder /app/build ./build
EXPOSE 3000
CMD ["serve", "-s", "build", "-l", "3000"]
