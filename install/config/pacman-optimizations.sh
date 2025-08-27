#!/bin/bash

# Install required packages
sudo pacman -S --noconfirm --needed reflector

# Optimize pacman configuration
if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
  # Add parallel downloads
  sudo sed -i '/^\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
  echo "Parallel downloads enabled in pacman"
fi

# Check and enable pacman cache cleanup
if ! systemctl is-enabled paccache.timer &>/dev/null; then
  sudo systemctl enable paccache.timer
  sudo systemctl start paccache.timer
  echo "Enabled automatic pacman cache cleanup"
fi

# Set up reflector for fastest mirrors
sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<EOF
# Reflector configuration file for automatic mirror selection

--save /etc/pacman.d/mirrorlist
--protocol https
--latest 20
--sort rate
--country 'United States,Germany,Canada,France,United Kingdom,Netherlands,Singapore,Japan'
EOF

# Create reflector systemd service
sudo tee /etc/systemd/system/reflector-update.service >/dev/null <<EOF
[Unit]
Description=Update pacman mirrors with reflector
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector @/etc/xdg/reflector/reflector.conf

[Install]
WantedBy=multi-user.target
EOF

# Create reflector systemd timer
sudo tee /etc/systemd/system/reflector-update.timer >/dev/null <<EOF
[Unit]
Description=Run reflector-update service weekly

[Timer]
OnBootSec=5min
OnUnitActiveSec=7d

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable reflector-update.timer
sudo systemctl start reflector-update.timer

# Run reflector once immediately to get the fastest mirrors
sudo reflector @/etc/xdg/reflector/reflector.conf

# Enable and configure makepkg for faster builds
if [ -f /etc/makepkg.conf ]; then
  # Set number of cores for compilation
  CORES=$(nproc)
  if grep -q "^#MAKEFLAGS" /etc/makepkg.conf; then
    sudo sed -i "s/^#MAKEFLAGS.*/MAKEFLAGS=\"-j$CORES\"/" /etc/makepkg.conf
  elif grep -q "^MAKEFLAGS" /etc/makepkg.conf; then
    sudo sed -i "s/^MAKEFLAGS.*/MAKEFLAGS=\"-j$CORES\"/" /etc/makepkg.conf
  else
    echo "MAKEFLAGS=\"-j$CORES\"" | sudo tee -a /etc/makepkg.conf >/dev/null
  fi
  echo "Updated makepkg.conf to use $CORES cores for compilation"
fi

# Enable systemwide delta compression if not already enabled
if ! grep -q "^UseDelta" /etc/pacman.conf; then
  sudo sed -i '/^\[options\]/a UseDelta = 0.7' /etc/pacman.conf
  echo "Enabled delta packages in pacman"
fi

echo "Pacman optimizations completed"
