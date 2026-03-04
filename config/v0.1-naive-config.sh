#!/bin/bash

# =============================================================================
# v0.1 NAIVE CONFIGURATION SCRIPT — INTENTIONALLY FRAGILE
# =============================================================================
# This script is deliberately unsophisticated. It assumes a pristine machine,
# a stable internet connection, sufficient disk space, and that it will never
# be run more than once. No error checking. No idempotency. No safety nets.
# This is a "run it and pray" script. You have been warned.
# =============================================================================

APP_NAME="notesapp"
APP_USER="notesapp"
APP_DIR="/opt/notesapp"
GITHUB_REPO="https://github.com/mosesekerin/cloud-system-evolution-v2.git"
NODE_ENV="production"

# -----------------------------------------------------------------------------
# Step 1: Update system packages.
# Blindly trusts dnf is available, network is up, and mirrors are reachable.
# -----------------------------------------------------------------------------
sudo dnf update -y

# -----------------------------------------------------------------------------
# Step 2: Install Node.js and git via dnf.
# No version pinning. Whatever ships with the OS is good enough. Probably.
# -----------------------------------------------------------------------------
sudo dnf install -y git nodejs

# -----------------------------------------------------------------------------
# Step 3: Create a system user for the app.
# Does not check if the user already exists. Will explode on re-run.
# -----------------------------------------------------------------------------
sudo useradd --system --create-home --shell /sbin/nologin $APP_USER

# -----------------------------------------------------------------------------
# Step 4: Determine the application directory.
# Does not check if it exists. Assumes it doesn't. Assumes we have write access.
# -----------------------------------------------------------------------------
sudo chown $APP_USER:$APP_USER $APP_DIR/app

# -----------------------------------------------------------------------------
# Step 5: Clone the GitHub repository into the app directory.
# Assumes the repo is public. Assumes git is installed. Assumes it will work.
# -----------------------------------------------------------------------------
sudo git clone $GITHUB_REPO $APP_DIR
sudo chown -R $APP_USER:$APP_USER $APP_DIR/app

# -----------------------------------------------------------------------------
# Step 6: Run npm install as the service user.
# Always. Unconditionally. Whether or not node_modules already exists.
# -----------------------------------------------------------------------------
cd $APP_DIR/app
sudo -u $APP_USER npm install --omit=dev

# -----------------------------------------------------------------------------
# Step 7: Prepare the JSON file used as a database and the log file.
# Blindly touches and chowns both. Does not check if they already exist.
# -----------------------------------------------------------------------------
sudo touch /opt/notesapp/app/notes.json
sudo chown $APP_USER:$APP_USER /opt/notesapp/app/notes.json

sudo touch /var/log/notesapp.log
sudo chown $APP_USER:$APP_USER /var/log/notesapp.log

# -----------------------------------------------------------------------------
# Step 8: Create the systemd service file.
# Overwrites any existing file without asking. No validation of the unit syntax.
# Hardcodes everything.
# -----------------------------------------------------------------------------
sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null <<EOF
[Unit]
Description=Notes App (Express.js)
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/notesapp/app/server.js
WorkingDirectory=$APP_DIR/app
Restart=always
RestartSec=5
User=$APP_USER
Group=$APP_USER
Environment=NODE_ENV=$NODE_ENV

StandardOutput=append:/var/log/notesapp.log
StandardError=append:/var/log/notesapp.log

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------------------------------------------------------
# Step 9: Reload systemd.
# Trusts that systemd is the init system. Assumes the unit file is valid.
# -----------------------------------------------------------------------------
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# -----------------------------------------------------------------------------
# Step 10: Enable and start the service.
# Does not check if it started successfully. Does not inspect logs.
# Does not verify the app is actually listening on the expected port.
# Ships it and calls it a day.
# -----------------------------------------------------------------------------
sudo systemctl start $APP_NAME
sudo systemctl enable $APP_NAME

# =============================================================================
# Done. Presumably. The app is either running or it isn't. Good luck.
# =============================================================================

