FROM node:22-alpine

USER nobody
WORKDIR /usr/src/app
COPY package.json ./

RUN yarn install

COPY . .

EXPOSE 3001

CMD ["node", "server.js"]