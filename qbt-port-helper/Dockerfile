FROM alpine:latest
RUN apk add --no-cache bash curl jq
WORKDIR /scripts
COPY pia-port.sh .
RUN chmod +x pia-port.sh
CMD ./pia-port.sh $USER $PASSWORD