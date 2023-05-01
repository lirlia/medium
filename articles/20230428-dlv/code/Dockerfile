FROM golang:1.19 as builder
WORKDIR /go/src/app
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 go build -o /bin/main main.go

FROM scratch
COPY --from=builder /bin/main /main
ENTRYPOINT ["/main"]
