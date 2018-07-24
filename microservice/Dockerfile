FROM golang:1.9.2 as builder
ARG SOURCE_LOCATION=/
WORKDIR ${SOURCE_LOCATION}
RUN go get -d -v github.com/go-kit/kit/endpoint \
      && go get -d -v github.com/go-logfmt/logfmt \
      && go get -d -v github.com/go-stack/stack
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM alpine:latest  
ARG SOURCE_LOCATION=/
RUN apk --no-cache add curl
EXPOSE 8080
WORKDIR /root/
COPY --from=builder ${SOURCE_LOCATION} .
CMD ["/root/go/app"] 
