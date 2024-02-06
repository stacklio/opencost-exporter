FROM golang:1.19-alpine

WORKDIR /app

COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY . .

RUN go build -o opencost-exporter cmd/opencost-exporter/main.go 

EXPOSE 9100

CMD [ "/app/opencost-exporter" ]