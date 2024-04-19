TOR-quick
===

`tor-quick` is a simple docker container
for setting up a hidden service and forwarding traffic to specified addresses.

A minimal compose stack could look like this:

```yaml
services:
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: 80:127.0.0.1:8000
```

This will create a hidden service that forwards traffic on the listening port 80 to 127.0.0.1:8000.
You can also combine `tor-quick` with a server, that should be accessible as a hidden service,
in the compose stack:

```yaml
services:
  webserver:
    image: crccheck/hello-world
    container_name: hello-world-webserver
    ports:
      - 8000:8000
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: 80:webserver:8000
```

To use a specific onion address instead of generating a random one,
you can supply the hidden service directory (containing the hostname and key) as a volume:

```yaml
services:
  webserver:
    image: crccheck/hello-world
    container_name: hello-world-webserver
    ports:
      - 8000:8000
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: 80:webserver:8000
      volumes:
        - ./hidden_service:/var/lib/tor/hidden_service
```

If you want to use a random onion address, but still want it to persist between restarts,
you can use an empty directory or named volume:

```yaml
services:
  webserver:
    image: crccheck/hello-world
    container_name: hello-world-webserver
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: 80:webserver:8000
      volumes:
        - hidden_service:/var/lib/tor/hidden_service

volumes:
  hidden_service:
```

The `.onion` address of your hidden service will be printed to the logs:

```shell
$ docker logs tor-quick | grep "Hidden service address"
```

Multiple forwards can be set up by specifying numbered `FORWARD_ADDR` environment variables:

```yaml
services:
  tor-quick:
    image: ghcr.io/felix-zenk/tor-quick:latest
    container_name: tor-quick
    environment:
      FORWARD_ADDR1: 80:webserver:8000
      FORWARD_ADDR2: 22:sshserver:22
```

> Keep in mind, that [not every listening port can be used](https://support.torproject.org/relay-operators/default-exit-ports/)
> and relay operators may constrain the useable ports further.

To view the active forwards:

```shell
$ docker logs tor-quick | grep "Hidden services"
```

