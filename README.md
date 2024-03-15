TOR-quick
===

`tor-quick` is a simple docker container
that sets up a hidden service and forwards HTTP traffic to a specified address.

A minimal compose stack could look like this:

```yaml
services:
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: 127.0.0.1:80
```

This will create a hidden service that forwards HTTP traffic to the localhost.
You can also combine `tor-quick` with a webserver, that should be accessible as a hidden service,
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
        FORWARD_ADDR: webserver:8000
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
        FORWARD_ADDR: webserver:8000
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
    ports:
      - 8000:8000
  tor-quick:
      image: ghcr.io/felix-zenk/tor-quick:latest
      container_name: tor-quick
      environment:
        FORWARD_ADDR: webserver:8000
      volumes:
        - hidden_service:/var/lib/tor/hidden_service

volumes:
  hidden_service:
```

If you do not use a specific onion address,
the randomly generated address will be printed to the logs:

```shell
$ docker logs tor-quick | grep "Hidden service address"
```

will print the onion address.
