#!/bin/bash

# =============================================================================
# v0.1 NAIVE CLEANUP SCRIPT — INTENTIONALLY FRAGILE
# =============================================================================
# Tears everything down. No checks. No confirmations. No mercy.
# Assumes everything exists. Will fail loudly if it doesn't.
# Run once. Hope for the best.
# =============================================================================

APP_NAME="notesapp"
APP_USER="notesapp"
APP_DIR="/opt/notesapp"

# -----------------------------------------------------------------------------
# Stop the service.
# Does not check if it is running. Does not wait for graceful shutdown.
# -----------------------------------------------------------------------------
sudo systemctl stop $APP_NAME

# -----------------------------------------------------------------------------
# Remove the app directory.
# Blindly nukes everything. No backup. No confirmation.
# -----------------------------------------------------------------------------
sudo rm -rf $APP_DIR

# -----------------------------------------------------------------------------
# Delete the system user.
# Does not check if the user exists. Does not check for running processes.
# -----------------------------------------------------------------------------
sudo userdel $APP_USER

# -----------------------------------------------------------------------------
# Remove the systemd unit file.
# Does not reload systemd after. Ghosts will linger in systemctl list-units.
# -----------------------------------------------------------------------------
sudo rm -f /etc/systemd/system/$APP_NAME.service

# -----------------------------------------------------------------------------
# Remove the log file.
# Gone. No archiving. No rotation. Just deleted.
# -----------------------------------------------------------------------------
sudo rm -f /var/log/notesapp.log

# =============================================================================
# Done. Presumably. The machine is either clean or it isn't. Good luck.
# =============================================================================

