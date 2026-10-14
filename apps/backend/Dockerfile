FROM node:20-alpine

WORKDIR /usr/src/app

COPY server.js .

USER 1000:1000

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["node", "server.js"]
