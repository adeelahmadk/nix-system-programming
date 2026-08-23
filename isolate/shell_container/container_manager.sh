#!/usr/bin/env bash

# =========================================================================== #
# Automated cgroups v2 Raw Linux Container Setup & Teardown Script            #
# =========================================================================== #
#                                                                             #
# Script:         container_manager.sh                                        #
# Version:        0.3.0                                                       #
# Author:         Adeel Ahmad (adeelahmadk)                                   #
# Date Created:   Aug 19, 2026                                                #
# Date Modified:  Aug 23, 2026                                                #
# Usage:          container_manager.sh setup -b DIR1:DIR2 -m 100M -c 25       #
#                                                                             #
# Prerequisites:                                                              #
#   - Run on a system running modern cgroups v2                               #
#   - Execute with root privileges (sudo)                                     #
#   - Required packages: wget, iptables, iproute2, coreutils                  #
# =========================================================================== #

usage() {
  echo "Usage: sudo $0 setup [options]"
  echo "       sudo $0 attach <PID>"
  echo "       sudo $0 cleanup"
  echo ""
  echo "Options for setup:"
  echo "  -b <HOSTDIR>[:GUESTDIR]   Bind a host dir to a guest dir or /mnt/host_data in the sandbox"
  echo "  -m <limit>                Set a cgroups v2 memory limit (e.g., '100M', '512M' or absolute bytes)"
  echo "  -c <pct>                  Set a cgroups v2 CPU percentage limit (e.g., 25: 25% of 1 core, 200: 2 cores)"
  echo "  -h | help                 Print this help"
}

error_exit() {
  usage
  exit 1
}

if [ $# -lt 1 ]; then
  error_exit
fi

# Strictly enforce root runtime safety
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please execute this script using sudo or as the root user."
  exit 1
fi

# Helper to normalize memory strings to absolute bytes for cgroups v2
parse_memory() {
  local mem_input="$1"
  if [[ "$mem_input" =~ ^[0-9]+[mM]$ ]]; then
    echo $((${mem_input%[mM]} * 1024 * 1024))
  elif [[ "$mem_input" =~ ^[0-9]+[gG]$ ]]; then
    echo $((${mem_input%[gG]} * 1024 * 1024 * 1024))
  elif [[ "$mem_input" =~ ^[0-9]+$ ]]; then
    echo "$mem_input"
  else
    echo "Error: Invalid memory format choice: '$mem_input'. Use e.g. 100M or 1G." >&2
    exit 1
  fi
}

# --- Configuration Variables ---
BRIDGE_IP="10.0.0.1"
GUEST_IP="10.0.0.2"
SUBNET="10.0.0.0/24"
CGROUP_NAME="my_container"
NS_ANCHOR_FILE=".ns_anchor.pid"
BIND_MOUNT_FILENAME=".bind.mount"
ROOTFS_LINK="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz"

# Define persistent absolute structural paths
BASE_DIR="/tmp/raw_container"
BASE="$BASE_DIR/base"
UPPER="$BASE_DIR/upper"
WORK="$BASE_DIR/work"
MERGED="$BASE_DIR/merged"
CGROUP_PATH="/sys/fs/cgroup/$CGROUP_NAME"
NS_ANCHOR="$BASE_DIR/$NS_ANCHOR_FILE"
BIND_MOUNTS_LIST_PATH="$BASE_DIR/$BIND_MOUNT_FILENAME"
DEFAULT_MNT_TARGET="/mnt/host_data"
CONTAINER_MOUNT_TARGET=
host_bind_path=""
mem_limit=""
cpu_pct=""

setup_container() {
  echo "=== Step 1: Initializing Workspace Structures ==="
  mkdir -p "$BASE" "$UPPER" "$WORK" "$MERGED"

  echo "=== Step 2: Extracting Alpine Linux Core OS ==="
  if [ ! -f "$BASE_DIR/alpine-minirootfs.tar.gz" ]; then
    echo " [+] Fetching minimal Alpine Linux root filesystem..."
    wget -q --show-progress \
      -O "$BASE_DIR/alpine-minirootfs.tar.gz" \
      "$ROOTFS_LINK"
  fi

  # Only extract if base looks unpopulated
  if [ ! -d "$BASE/bin" ]; then
    tar -xf "$BASE_DIR/alpine-minirootfs.tar.gz" -C "$BASE"
  fi

  echo "=== Step 3: Structuring OverlayFS layers ==="
  # Avoid stack duplication if already mounted
  if ! mountpoint -q "$MERGED"; then
    echo " [+] Linking file stack layers via OverlayFS..."
    mount -t overlay overlay \
      -o lowerdir="$BASE",upperdir="$UPPER",workdir="$WORK" "$MERGED"
  fi

  # Handle Host Directory Binding Feature if specified
  if [ -n "$host_bind_path" ]; then
    # Convert to absolute path to guarantee absolute stability across namespaces
    ABS_BIND_PATH=$(realpath "$host_bind_path")

    if [ ! -d "$ABS_BIND_PATH" ]; then
      echo "Error: Specified host path '$ABS_BIND_PATH' does not exist."
      cleanup_container
      exit 1
    fi

    # CONTAINER_MOUNT_TARGET="$MERGED/mnt/host_data"
    echo "=== Step 3.1: Binding Host Directory ($ABS_BIND_PATH) ==="
    mkdir -p "$CONTAINER_MOUNT_TARGET"

    # Bind mount the host directory to the overlay merged tree
    mount --bind "$ABS_BIND_PATH" "$CONTAINER_MOUNT_TARGET"
    echo "$CONTAINER_MOUNT_TARGET" >"$BIND_MOUNTS_LIST_PATH"
    echo " [+] Bound successfully to container path: $2"
  fi

  echo "=== Step 4: Spawning Namespace Anchor ==="
  echo " [+] Securing kernel boundaries and initializing context stack..."
  # Start a persistent sleep background anchor to hold the isolated namespaces open
  # This acts as our persistent PID 1/Container engine layer until explicitly managed.
  unshare --fork --pid --uts --ipc --net --mount sleep infinity &
  NS_PID=$!
  # Store the background network/namespace target anchor PID safely
  echo "$NS_PID" >"$NS_ANCHOR"
  echo " [+] Namespace anchor spawned successfully on Host PID: $NS_PID"

  echo "=== Step 5: Provisioning Unified cgroups v2 Targets ==="
  echo " [+] Enforcing resource constraints via cgroups v2..."
  mkdir -p "$CGROUP_PATH"

  # Handle memory threshold setup dynamically if requested
  if [ -n "$mem_limit" ]; then
    # Enable the memory controller down the tree for sub-cgroups
    echo "+memory" >/sys/fs/cgroup/cgroup.subtree_control 2>/dev/null

    BYTES_LIMIT=$(parse_memory "$mem_limit")
    echo "$BYTES_LIMIT" >"$CGROUP_PATH/memory.max"
    echo " [+] Applied cgroups v2 memory limit: $mem_limit ($BYTES_LIMIT bytes)"
  fi

  # Handle CPU threshold calculations dynamically if requested
  if [ -n "$cpu_pct" ]; then
    if [[ ! "$cpu_pct" =~ ^[0-9]+$ ]]; then
      echo "Error: CPU value must be a positive integer percentage."
      cleanup_container
      exit 1
    fi

    # Enable the CPU controller down the tree for sub-cgroups
    echo "+cpu" >/sys/fs/cgroup/cgroup.subtree_control 2>/dev/null

    # cgroups v2 uses: 'quota period' structure.
    # Default tracking period is 100000 microseconds (100ms).
    PERIOD=100000
    QUOTA=$(((PERIOD * cpu_pct) / 100))

    # Write both parameters to cpu.max: "quota period"
    echo "$QUOTA $PERIOD" >"$CGROUP_PATH/cpu.max"
    echo " [+] applied cgroups v2 CPU limit: $cpu_pct% (Quota: $QUOTA, Period: $PERIOD)"
  fi

  # Track both the namespace anchor and upcoming processes inside the cgroup
  echo "$NS_PID" >"$CGROUP_PATH/cgroup.procs"

  echo "=== Step 6: Engineering Isolated Network veth Bridge ==="
  echo " [+] Injecting virtual communication interface pair..."
  # 1. Wire host to guest adapter pair
  ip link add vfhost type veth peer name vfguest
  # 2. Inject target end down into the background anchor's network space
  ip link set vfguest netns "$NS_PID"
  # 3. Configure the host tracking edge
  ip addr add "$BRIDGE_IP/24" dev vfhost
  ip link set vfhost up

  # 4. Jump internally to safely bind guest adapters and assign routing
  nsenter -t "$NS_PID" -n ip link set lo up
  nsenter -t "$NS_PID" -n ip addr add "$GUEST_IP/24" dev vfguest
  nsenter -t "$NS_PID" -n ip link set vfguest up
  nsenter -t "$NS_PID" -n ip route add default via "$BRIDGE_IP"

  # 5. Enable internet packet forwarding through Network Address Translation (NAT)
  echo " [+] Deploying internal route masquerading rules (NAT)..."
  iptables -t nat -A POSTROUTING -s "$SUBNET" -j MASQUERADE

  echo " [+] Configuring container domain name resolver..."
  # Configure proper container DNS name resolution
  echo "nameserver 8.8.8.8" >"$MERGED/etc/resolv.conf"

  echo "=== Step 7: Accessing Container Environment (chroot) ==="
  echo "Entering your secure sandbox now. Type 'exit' to return back to the host."
  echo "--------------------------------------------------------"

  # Run absolute path target definitions using the persistent nsenter runtime context
  nsenter -t "$NS_PID" -m -u -i -n \
    chroot "$MERGED" /bin/sh -c \
    "mount -t proc proc /proc && exec /bin/sh"

  echo "[*] Shell exited. The background container process ($NS_PID) is still alive."
  echo "[*] Execute '$0 cleanup' to safely purge all resources."
}

cleanup_container() {
  echo "=== Beginning Destructive Sandbox Cleanup Pipeline ==="

  # 1. Neutralize running container processes
  if [ -f "$NS_ANCHOR" ]; then
    NS_PID=$(cat "$NS_ANCHOR")
    echo " [+] Terminating tracking namespace anchor process (PID: $NS_PID)..."
    kill -9 "$NS_PID" 2>/dev/null
    rm "$NS_ANCHOR"
  fi

  # 2. Flush Virtual Ethernet Pipelines
  if ip link show vfhost &>/dev/null 2>&1; then
    echo " [+] Deleting virtual interface link: vfhost..."
    ip link del vfhost
  fi

  # 3. Flush associated masqueraded routing rules
  echo " [+] Cleaning NAT network routing tables..."
  iptables -t nat -D POSTROUTING -s "$SUBNET" -j MASQUERADE 2>/dev/null || true

  # 4a. Safely release directory bind mounts if present
  if [ -f "$BIND_MOUNTS_LIST_PATH" ]; then
    CONTAINER_MOUNT_TARGET=$(cat "$BIND_MOUNTS_LIST_PATH")
    echo " [+] Found bind mount under $CONTAINER_MOUNT_TARGET"
    if mountpoint -q "$CONTAINER_MOUNT_TARGET" 2>/dev/null; then
      echo " [+] Unmounting bounded host directory mount under $CONTAINER_MOUNT_TARGET..."
      umount -f "$CONTAINER_MOUNT_TARGET"
      rm -rf "$CONTAINER_MOUNT_TARGET"
    fi
    rm "$BIND_MOUNTS_LIST_PATH"
  fi

  # 4b. Unmount underlying OverlayFS
  if mountpoint -q "$MERGED"; then
    echo " [+] Unmounting workspace overlay layer safely..."
    umount -f "$MERGED"
  fi

  # 5. Clean cgroups v2 control paths
  if [ -d "$CGROUP_PATH" ]; then
    echo " [+] De-allocating unified cgroups v2 tree blocks..."
    # Under cgroups v2, we kill all trailing processes inside before deletion
    if [ -f "/sys/fs/cgroup/$CGROUP_NAME/cgroup.kill" ]; then
      echo "1" >"/sys/fs/cgroup/$CGROUP_NAME/cgroup.kill" || true
    fi
    sleep 0.2
    rmdir "$CGROUP_PATH" 2>/dev/null || true
  fi

  # 6. Delete directory contents
  # Todo: Only remove the overlayfs dirs, keep the initrd/rootfs
  if [ -d "$BASE" ]; then
    echo " [+] Purging workspace file footprint under $BASE_DIR..."
    rm -rf "$BASE" "$UPPER" "$WORK" "$MERGED"
  fi

  echo "=== Cleanup completed successfully. Host environment is clean. ==="
}

attach_container() {
  if mountpoint -q "$MERGED"; then
    # Run absolute path target definitions using the persistent nsenter runtime context
    nsenter -t "$1" -m -u -i -n \
      chroot "$MERGED" /bin/sh
  else
    echo " [-] No OverlayFS mounted from $MERGED"
  fi
}

parse_options() {
  while getopts "b:m:c:" opt; do
    case "$opt" in
    b)
      IFS=: read SRC DST <<<"$OPTARG"
      host_bind_path="$SRC"
      # fallback to default destination
      if [ -z "$DST" ]; then DST="$DEFAULT_MNT_TARGET"; fi
      CONTAINER_MOUNT_TARGET="${MERGED}${DST}"
      ;;
    m) mem_limit="$OPTARG" ;;
    c) cpu_pct="$OPTARG" ;;
    \?) error_exit ;;
    esac
  done
}

# -- Main Command-Line Orchestrator Switch --
ACTION="$1"
if [ -z "$ACTION" ]; then
  echo "Command has no action!"
  error_exit
fi

case "$ACTION" in
setup)
  shift              # Remove "setup" from the list, make getopts see the flags
  parse_options "$@" # Pass the remaining arguments
  setup_container
  ;;
attach)
  if [ $# -ne 2 ]; then error_exit; fi
  attach_container "$2"
  ;;
cleanup)
  cleanup_container
  ;;
help | -h)
  usage
  ;;
*)
  error_exit
  ;;
esac
