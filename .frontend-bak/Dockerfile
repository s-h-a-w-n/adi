# Frontend Dockerfile
FROM node:22-alpine AS build

WORKDIR /app
COPY package.json ./
COPY yarn.lock ./
RUN yarn install

COPY . ./
# Set NODE_OPTIONS to use legacy OpenSSL providers and skip preflight check
ENV NODE_OPTIONS=--openssl-legacy-provider
ENV SKIP_PREFLIGHT_CHECK=true
RUN yarn build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
