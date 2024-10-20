FROM node:22-alpine AS build

WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install

COPY . ./
RUN yarn build

FROM nginx:alpine

# Create necessary directories and set permissions
RUN mkdir -p /var/cache/nginx && \
  chown -R nobody:nogroup /var/cache/nginx /etc/nginx/conf.d

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]