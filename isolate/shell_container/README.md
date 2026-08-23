# Linux Container with Bash

Container Manager is a Bash script that creates an isolated environment inside a directory.

- Sets up an Overlay FS with [Alpine rootfs](https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.0-x86_64.tar.gz) as lower layer
- Creates an isolated kernel namespace for the sandbox
- `chroot` into merged layer
- Sets up physical resource restraints and process tracking via `cgroups v2`
- Builds and attaches virtual network stack via bridge adapter
- Enables packet forwarding via NAT
- if user sends arguments, **bind mounts** a host directory inside the sandbox.

## Usage

```
Usage: sudo ./sandbox.sh setup [options]
       sudo ./sandbox.sh attach <PID>
       sudo ./sandbox.sh cleanup

Options for setup:
  -b <HOSTDIR>[:GUESTDIR]   Bind a host dir to a guest dir or /mnt/host_data inside the sandbox
  -m <limit>                Set a cgroups v2 memory limit (e.g., '100M', '512M' or absolute bytes)
  -c <pct>                  Set a cgroups v2 CPU percentage limit (e.g., '25': 25% of 1 core, '200': 2 cores)
  -h | help                 Print this help
```

## Examples

Just setup a container:

```shell
sudo ./container_manager.sh setup
```

Or, mount a directory and set resource restrictions:

```shell
sudo ./container_manager.sh setup -b ./data:/root/data -m 100M -c 25
```

Attach to a sandbox:

```shell
sudo ./container_manager.sh attach 12345
```

Destroy a sandbox:

```shell
sudo ./container_manager.sh cleanup

```
