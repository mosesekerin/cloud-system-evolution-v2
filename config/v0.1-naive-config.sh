#!/bin/bash

# =============================================================================
# v0.3 IDEMPOTENT BASELINE — SAFE RE-EXECUTION
# =============================================================================
# Upgraded from v0.2 to introduce idempotency for user and directory creation.
#
# What changed:
#   - User creation is skipped if the user already exists.
#   - Application directory creation is skipped if it already exists.
#   - App directory is only cloned if destination is empty.
#   - notes.json and log file are only created if they do not already exist.
#   - systemd service is only reloaded if the unit file changed.
#   - Service is only restarted if it was already running.
#   - Script is now safe to re-run on a partially or fully provisioned machine.
#
# What did NOT change:
#   - Still NOT concurrency-safe. No locking. No mutex. No guards.
#   - Still enforces set -euo pipefail and fail-fast behavior from v0.2.
#   - Still uses structured log() and error() functions with timestamps.
#   - Still traps ERR and reports failing line number.
#   - Provisioning logic, step ordering, and commands are otherwise unchanged.
#
# This version enforces: skip what already exists, fail fast on anything else.
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

APP_NAME="notesapp"
APP_USER="notesapp"
APP_DIR="/opt/notesapp"
GITHUB_REPO="https://github.com/mosesekerin/cloud-system-evolution-v2.git"
NODE_ENV="production"

# -----------------------------------------------------------------------------
# Logging and error handling.
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

trap 'error "Script failed at line ${LINENO}. Exiting."' ERR

# -----------------------------------------------------------------------------
# Step 1: Update system packages.
# -----------------------------------------------------------------------------
log "Step 1: Updating system packages."
sudo dnf update -y

# -----------------------------------------------------------------------------
# Step 2: Install Node.js and git via dnf.
# dnf install -y is already idempotent by nature.
# -----------------------------------------------------------------------------
log "Step 2: Installing git and nodejs."
sudo dnf install -y git nodejs

# -----------------------------------------------------------------------------
# Step 3: Create a system user for the app.
# Skipped if the user already exists.
# -----------------------------------------------------------------------------
log "Step 3: Creating system user '${APP_USER}' if not present."
if id "$APP_USER" &>/dev/null; then
    log "User '${APP_USER}' already exists. Skipping."
else
    sudo useradd --system --create-home --shell /sbin/nologin $APP_USER
fi

# -----------------------------------------------------------------------------
# Step 4: Create the application directory.
# Skipped if the directory already exists.
# -----------------------------------------------------------------------------
log "Step 4: Creating application directory if not present."
if [ -d "$APP_DIR" ]; then
    log "Directory '${APP_DIR}' already exists. Skipping creation."
else
    sudo mkdir -p $APP_DIR
    sudo chown $APP_USER:$APP_USER $APP_DIR
fi

# -----------------------------------------------------------------------------
# Step 5: Clone the GitHub repository into the app directory.
# Skipped if the directory is already populated.
# -----------------------------------------------------------------------------
log "Step 5: Cloning repository from ${GITHUB_REPO} if not already cloned."
if [ -d "$APP_DIR/.git" ]; then
    log "Repository already cloned at '${APP_DIR}'. Skipping."
else
    sudo git clone $GITHUB_REPO $APP_DIR
    sudo chown -R $APP_USER:$APP_USER $APP_DIR/app
fi

# -----------------------------------------------------------------------------
# Step 6: Run npm install as the service user.
# Always runs. node_modules state is not checked.
# -----------------------------------------------------------------------------
log "Step 6: Running npm install as '${APP_USER}'."
cd $APP_DIR/app
sudo -u $APP_USER npm install --omit=dev

# -----------------------------------------------------------------------------
# Step 7: Prepare the JSON file used as a database and the log file.
# Both are only created if they do not already exist.
# -----------------------------------------------------------------------------
log "Step 7: Preparing notes.json and log file if not present."
if [ ! -f "/opt/notesapp/app/notes.json" ]; then
    sudo touch /opt/notesapp/app/notes.json
    sudo chown $APP_USER:$APP_USER /opt/notesapp/app/notes.json
else
    log "notes.json already exists. Skipping."
fi

if [ ! -f "/var/log/notesapp.log" ]; then
    sudo touch /var/log/notesapp.log
    sudo chown $APP_USER:$APP_USER /var/log/notesapp.log
else
    log "notesapp.log already exists. Skipping."
fi

# -----------------------------------------------------------------------------
# Step 8: Create the systemd service file.
# Writes the unit file and only reloads systemd if the file changed.
# -----------------------------------------------------------------------------
log "Step 8: Writing systemd unit file to /etc/systemd/system/${APP_NAME}.service."
UNIT_FILE="/etc/systemd/system/$APP_NAME.service"
UNIT_CHANGED=false

NEW_UNIT=$(cat <<EOF
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
)

if [ ! -f "$UNIT_FILE" ] || [ "$(sudo cat $UNIT_FILE)" != "$NEW_UNIT" ]; then
    echo "$NEW_UNIT" | sudo tee $UNIT_FILE > /dev/null
    UNIT_CHANGED=true
    log "Unit file written or updated."
else
    log "Unit file unchanged. Skipping write."
fi

# -----------------------------------------------------------------------------
# Step 9: Reload systemd only if the unit file changed.
# -----------------------------------------------------------------------------
log "Step 9: Reloading systemd if unit file changed."
if [ "$UNIT_CHANGED" = true ]; then
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
else
    log "No unit file changes detected. Skipping daemon reload."
fi

# -----------------------------------------------------------------------------
# Step 10: Enable and start the service.
# Restarts the service if it is already running, starts it if it is not.
# -----------------------------------------------------------------------------
log "Step 10: Enabling and starting '${APP_NAME}' service."
sudo systemctl enable $APP_NAME

if sudo systemctl is-active --quiet $APP_NAME; then
    log "Service '${APP_NAME}' is already running. Restarting to apply any changes."
    sudo systemctl restart $APP_NAME
else
    sudo systemctl start $APP_NAME
fi

log "Provisioning complete. Service '${APP_NAME}' is running."

# =============================================================================
# Done. The script is safe to re-run. State was reconciled where possible.
# =============================================================================