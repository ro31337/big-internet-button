#\!/bin/bash
ROUTER_HOST="root@openwrt.lan"
ssh_exec() {
    ssh -o ConnectTimeout=5 -o ServerAliveInterval=2 -o ServerAliveCountMax=2 "$ROUTER_HOST" "$@"
}

echo "Testing which nohup..."
if \! ssh_exec "which nohup" >/dev/null 2>&1; then
    echo "nohup not found"
else
    echo "nohup found"
fi

echo "Testing which fake_command..."
if \! ssh_exec "which fake_command" >/dev/null 2>&1; then
    echo "fake_command not found"
else
    echo "fake_command found"
fi
