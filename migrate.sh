#!/usr/bin/env bash
set -euo pipefail

###
### Untested proof-of-concept migration script
###
### Features:
### - tracking progess
### - graceful exit on any error
### - resuming from any step
###
### Missing:
### - generating recovery keys
###
### Caveat:
### - does not move existing revovery key to new account
### - manual steps neccessary for this currently
### 
### !!! Use at your own risk. Feedback welcome. !!!
### 

# --- Begin config ---

# --- Old (mushroom) account settings ---
OLD_PDS_HOST="https://cordyceps.us-west.host.bsky.network"
OLD_HANDLE="yourhandle.dev"
OLD_PASSWORD="old_password_here"

# --- New (self-hosted) account settings ---
NEW_PDS_HOST="https://example.com"
NEW_HANDLE="yourhandle.example.com"
NEW_PASSWORD="new_password_here"
NEW_EMAIL="you@example.com"
INVITE_CODE="paste_your_invite_code_here"

# --- Workspace & filenames ---
WORKDIR="$HOME/bsky_migration"
STATE_FILE="$WORKDIR/.migration_state"
CAR_FILE="$WORKDIR/${OLD_HANDLE}.repo.car"
BLOBS_DIR="$WORKDIR/${OLD_HANDLE}_blobs"
PREFS_FILE="$WORKDIR/prefs.json"

# --- Replace this with "true" after changing account settings above ---
VALID_CONFIG="false" 

# --- End config ---

# Helper functions
log()    { printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
error()  { log "ERROR: $*"; save_state; exit 1; }
save_state() { echo "STEP=$CURRENT_STEP" >"$STATE_FILE"; }
check_rc()  { local rc=$?; (( rc == 0 )) || error "Step '$CURRENT_STEP' failed (rc=$rc)"; }
check_disk() {
  local dir=$1 min_mb=$2
  local avail
  avail=$(df --output=avail -m "$dir" | tail -n1)
  (( avail >= min_mb )) || error "Need ≥${min_mb}MB free in $dir, have ${avail}MB"
}
trap 'error "Interrupted at step $CURRENT_STEP"' INT TERM

# Check if configuration settings are valid
if [[ ! "$VALID_CONFIG" == "true" ]]; then
  echo "Please change configuration settings first." >&2
  exit 1
fi

mkdir -p "$WORKDIR"

# --- Steps ---
function step_check_prereqs {
  CURRENT_STEP=check_prereqs
  log "Checking prerequisites..."

  command -v go >/dev/null || error "Go compiler not found; please install Go."
  if ! command -v goat >/dev/null; then
    log "goat not found; will install via Go."
  fi

  check_disk "$WORKDIR" 2048  # require ≥2GB free
  save_state
}

function step_install_goat {
  CURRENT_STEP=install_goat
  if ! command -v goat >/dev/null; then
    log "Installing goat..."
    GO111MODULE=on go install github.com/bluesky-social/indigo/cmd/goat@latest
    check_rc
    export PATH="$PATH:$HOME/go/bin"
    command -v goat >/dev/null || error "goat not found after install."
  else
    log "goat already installed; skipping."
  fi
  save_state
}

function step_export_repo {
  CURRENT_STEP=export_repo
  log "Logging in to old PDS..."
  goat account login --pds-host "$OLD_PDS_HOST" -u "$OLD_HANDLE" -p "$OLD_PASSWORD"
  check_rc

  log "Exporting repo to $CAR_FILE..."
  goat repo export "$OLD_HANDLE" --output "$CAR_FILE"
  save_state
}

function step_export_blobs {
  CURRENT_STEP=export_blobs
  log "Exporting blobs to $BLOBS_DIR..."
  mkdir -p "$BLOBS_DIR"
  goat blob export "$OLD_HANDLE" --output "$BLOBS_DIR"
  save_state
}

function step_export_prefs {
  CURRENT_STEP=export_prefs
  log "Exporting app preferences to $PREFS_FILE..."
  goat bsky prefs export >"$PREFS_FILE"
  save_state
}

function step_request_service_auth {
  CURRENT_STEP=request_service_auth
  log "Requesting service-auth token (check your email)..."
  SERVICEAUTH=$(goat account service-auth \
    --lxm com.atproto.server.createAccount \
    --duration-sec 3600 \
    --aud "did:web:${NEW_PDS_HOST#https://}")
  save_state
}

function step_create_new_account {
  CURRENT_STEP=create_new_account
  log "Creating new account on $NEW_PDS_HOST..."
  read -rp "Enter PLC token for account creation (from email): " PLC_TOKEN
  goat account create --service-auth "$SERVICEAUTH" \
    --pds-host "$NEW_PDS_HOST" \
    --existing-did "" \
    --handle "$NEW_HANDLE" \
    --password "$NEW_PASSWORD" \
    --email "$NEW_EMAIL" \
    --invite-code "$INVITE_CODE" \
    --plc-token "$PLC_TOKEN"
  save_state
}

function step_login_new {
  CURRENT_STEP=login_new
  log "Logging in to new PDS..."
  DID=$(goat account status | jq -r .did)
  goat account login --pds-host "$NEW_PDS_HOST" -u "$DID" -p "$NEW_PASSWORD"
  save_state
}

function step_import_repo {
  CURRENT_STEP=import_repo
  log "Importing repo CAR to new PDS..."
  goat repo import "$CAR_FILE"
  save_state
}

function step_upload_blobs {
  CURRENT_STEP=upload_blobs
  log "Uploading missing blobs..."
  MISSING=$(goat account missing-blobs | cut -f1)
  for cid in $MISSING; do
    if [[ -f "$BLOBS_DIR/$cid" ]]; then
      goat blob upload "$BLOBS_DIR/$cid" || log "WARN: upload of $cid failed"
    else
      log "WARN: local blob $cid not found; skipping"
    fi
  done
  save_state
}

function step_import_prefs {
  CURRENT_STEP=import_prefs
  log "Importing preferences..."
  goat bsky prefs import <"$PREFS_FILE"
  save_state
}

function step_prepare_plc {
  CURRENT_STEP=prepare_plc
  log "Generating recommended DID document..."
  goat account plc recommended >"$WORKDIR/plc_new.json"
  save_state
}

function step_sign_plc {
  CURRENT_STEP=sign_plc
  log "Requesting PLC operation token (check your email)..."
  goat account plc request-token
  read -rp "Enter PLC token for DID update: " PLC_TOKEN2
  goat account plc sign --token "$PLC_TOKEN2" "$WORKDIR/plc_new.json" \
    >"$WORKDIR/plc_new_signed.json"
  save_state
}

function step_submit_plc {
  CURRENT_STEP=submit_plc
  log "Submitting signed DID document..."
  goat account plc submit "$WORKDIR/plc_new_signed.json"
  save_state
}

function step_deactivate_old {
  CURRENT_STEP=deactivate_old
  log "Deactivating old account on $OLD_PDS_HOST..."
  goat account login --pds-host "$OLD_PDS_HOST" -u "$OLD_HANDLE" -p "$OLD_PASSWORD"
  goat account deactivate
  save_state
}

# --- Step dispatcher ---
case "$STEP" in
  check_prereqs)      step_check_prereqs;;&
  install_goat)       step_install_goat;;&
  export_repo)        step_export_repo;;&
  export_blobs)       step_export_blobs;;&
  export_prefs)       step_export_prefs;;&
  request_service_auth) step_request_service_auth;;&
  create_new_account) step_create_new_account;;&
  login_new)          step_login_new;;&
  import_repo)        step_import_repo;;&
  upload_blobs)       step_upload_blobs;;&
  import_prefs)       step_import_prefs;;&
  prepare_plc)        step_prepare_plc;;&
  sign_plc)           step_sign_plc;;&
  submit_plc)         step_submit_plc;;&
  deactivate_old)     step_deactivate_old;;&
  *)
    log "Migration complete, or unknown state '$STEP'."
    exit 0
    ;;
esac

# log "🎉 Migration completed successfully! 🎉"