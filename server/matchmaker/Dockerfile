FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/matchmaker .

FROM alpine:3.20
RUN adduser -D -u 10001 app
USER app
COPY --from=build /out/matchmaker /usr/local/bin/matchmaker
EXPOSE 8080
ENTRYPOINT ["matchmaker"]
