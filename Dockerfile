FROM golang:1.19-alpine

WORKDIR /app

COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY . .

RUN go build -o aws-cost-exporter cmd/aws-cost-exporter/main.go 

EXPOSE 9100

CMD [ "/app/aws-cost-exporter" ]