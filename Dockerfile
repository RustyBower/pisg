FROM perl:latest

VOLUME /cache /config /logs /nginx

WORKDIR /app

COPY . .

CMD ["/app/pisg"]
