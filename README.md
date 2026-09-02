# ACCEL-PPP SSTP Docker VPN Server

This is a Docker image for [ACCEL-PPP](https://accel-ppp.github.io/) configured as a SSTP VPN server.
It is designed to operate with https://github.com/nuclearcat/accel-ppp-miniadmin/ for easy management.

## Features

- ACCEL-PPP SSTP VPN server
- Operate within isolated Docker container
- Easy management with miniadmin

## Usage

Follow [guidelines](https://github.com/nuclearcat/accel-ppp-miniadmin/blob/main/README.md) at accel-ppp-miniadmin repository.

## Building

The image builds accel-ppp from git. The revision is pinned in the `Dockerfile`
via the `ACCEL_PPP_REF` build argument so that builds are reproducible and so
that bumping it invalidates docker's layer cache.

```sh
docker build -t nuclearcat/accel-ppp .
```

To update to the current upstream master, bump `ACCEL_PPP_REF` in the
`Dockerfile` to the desired commit, or override it for a one-off build:

```sh
docker build --build-arg ACCEL_PPP_REF=master --no-cache -t nuclearcat/accel-ppp .
```

## License

This project is licensed under the LGPL-2.1 License - see the [LICENSE](LICENSE) file for details.

