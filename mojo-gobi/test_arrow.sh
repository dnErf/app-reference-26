#!/bin/bash
cd /home/lnx/Dev/app-reference-26/mojo-gobi

# Start daemon in background
./daemon test_db &
DAEMON_PID=$!

# Wait for daemon to start
sleep 2

# Test client
python3 client.py status

# Kill daemon
kill $DAEMON_PID