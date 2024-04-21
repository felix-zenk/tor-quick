TOR-quick
===

[![Create and publish Docker image](https://github.com/felix-zenk/tor-quick/actions/workflows/publish.yml/badge.svg)](https://github.com/felix-zenk/tor-quick/actions/workflows/publish.yml)

`tor-quick` is a docker container for setting up an onion service and forwarding traffic to specified addresses.

---

A minimal compose stack could look like this:

```yaml
services:
  tor-quick:
    image: ghcr.io/felix-zenk/tor-quick:latest
    container_name: tor-quick
    environment:
      FORWARD_ADDR: 80:127.0.0.1:8000
```

This will create an onion service that forwards traffic on the listening port 80 to 127.0.0.1:8000.  
Have a look at [docker-compose.yaml](docker-compose.yaml) for a more complete example.  

Possible formats for `FORWARD_ADDR` are:

| Format                 | Listening Port | Forwarded to        |
|------------------------|----------------|---------------------|
| PORT:FWD_ADDR          | *.onion:PORT   | FWD_ADDR:PORT       |
| PORT:FWD_ADDR:FWD_PORT | *.onion:PORT   | FWD_ADDR:FWD_PORT   |
| *FWD_ADDR:FWD_PORT*    | *\*.onion:80*  | *FWD_ADDR:FWD_PORT* |


Additional environment variables can be set to configure the onion service further:

- `CHECK_DESTINATION`: If set to `true`, the destination addresses will be checked for reachability before starting the onion service.
  Helps to avoid misconfigurations.
- `ENABLE_VANGUARDS`: If set to `true`, the [Vanguards](https://github.com/mikeperry-tor/vanguards) addon will be enabled.
- `TORRC_EXTRA`: Additional configuration to append to the `torrc` file.

You can also combine `tor-quick` with a server, that should be accessible as an onion service,
in the compose stack and reference it by its service name:

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
you can supply the onion service directory (containing the hostname and key) as a volume:

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

The `.onion` address of your onion service will be printed to the logs:

```shell
$ docker logs tor-quick | grep "Onion Service address"
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
> and relay operators may constrain the usable ports further.

To view the active forwards:

```shell
$ docker logs tor-quick | grep "Hidden service"
```

