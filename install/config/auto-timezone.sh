#!/bin/bash

# Install tzupdate if not already installed
if ! command -v tzupdate &>/dev/null; then
  sudo pacman -S --noconfirm --needed tzupdate
fi

# Set up automatic timezone detection
# Check if automatic timezone detection service exists
if [ ! -f /etc/systemd/system/auto-timezone.service ] && [ ! -f /etc/systemd/system/auto-timezone.timer ]; then
  # Create systemd service for auto timezone detection
  sudo tee /etc/systemd/system/auto-timezone.service >/dev/null <<EOF
[Unit]
Description=Automatic timezone detection
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/tzupdate
User=root

[Install]
WantedBy=multi-user.target
EOF

  # Create systemd timer to run the service periodically
  sudo tee /etc/systemd/system/auto-timezone.timer >/dev/null <<EOF
[Unit]
Description=Run auto-timezone service periodically

[Timer]
OnBootSec=1min
OnUnitActiveSec=12h

[Install]
WantedBy=timers.target
EOF

  # Enable and start the timer
  sudo systemctl daemon-reload
  sudo systemctl enable auto-timezone.timer
  sudo systemctl start auto-timezone.timer
  
  # Run it once immediately
  sudo tzupdate
  
  echo "Automatic timezone detection has been set up."
fi
