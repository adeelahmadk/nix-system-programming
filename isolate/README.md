# Isolation: Linux Containerization

A Linux container is a lightweight, isolated environment for running applications and their dependencies. Unlike virtual machines (VMs) which emulate hardware and run a complete guest operating system, containers share the host system's Linux kernel. This approach makes them significantly more efficient and faster to start than VMs.

Key features of containers are:

- leverage the host's Linux kernel
- provide process, network, filesystem, and other resource isolation

## Writing from Scratch

Writing a container from scratch requires a deep understanding of three concepts in Linux kernel:
- [Namespaces](https://man7.org/linux/man-pages/man7/namespaces.7.html) 
- [Chroot](https://man7.org/linux/man-pages/man2/chroot.2.html)
- [Control Groups](https://man7.org/linux/man-pages/man7/cgroups.7.html)

## System Calls

- `exec`
- `chroot`
- `sethostname`
- `mount`
- `unmount`
- `mkdir`
- `rmdir`

## Programs

| Program          | Description                                                  |
| ---------------- | ------------------------------------------------------------ |
| `tiny_container` | Bare-bones container runs a process isolated by namespaces, chroot, and cgroups |
| `shell_container`  |  A Bash script that creates an isolated environment inside a directory.                                                             |

