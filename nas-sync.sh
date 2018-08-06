#!/bin/bash
# NAS Sync - v0.8

# Sync the latest version of a NAS Share to a union mounted directory, only downloading
# and keeping the newer/changed files, so that transfer times and used space is decreased
#
# NOTE
#
# If the underlying filesystem is XFS and doesn't have ftype=1, you will still see deleted files. 
# They just won't have any metadata or be usable. Make sure XFS was built like so: 
# mkfs.xfs -n ftype=1 /path/to/your/device. 
# EXT4 should be ok by default.
#
# EXTRA NOTE
#
# OverlayFS doesn't support SELinux labels until ~RHEL 7.4, before this you won't be able
# to export over NFS and the like using the OverlayFS mounted filesystems. Or you can 
# just disable SELinux.

# Rsync server details, specify username/password if required
RSYNC_SERVER="192.168.155.180"
RSYNC_USER=""
RSYNC_PASSWORD=""

# if we specify a user, update server details to include username
if [[ "${RSYNC_USER}" != "" ]]; then
  # rsync with specified username
  RSYNC_SERVER="${RSYNC_USER}@${RSYNC_SERVER}"
    # have to export the RSYNC_PASSWORD for it to work
  export RSYNC_PASSWORD
fi

# local pool root directory
POOL="/mnt/pool/NAS"
# Remote NAS share info (rsync structure)
NAS="/NAS/Data/"
# this week in numerical format
THISWEEK=$(date +%V)
# last week in numerical format
LASTWEEK=$(date -d '-1week' +%V)

# set our upper, lower and work directories to use
# set a log file so we can see if there were any failures
LOWERDIR="${POOL}/${LASTWEEK}"
UPPERDIR="${POOL}/${THISWEEK}"
WORKDIR="${POOL}/.wd/${THISWEEK}"
LOGFILE="${POOL}/${THISWEEK}.log"
MOUNT=$(mountpoint -q "${UPPERDIR}") 
LSMOD=$(lsmod|grep -q overlay)

# check if the overlay module is loaded, if not load it.
[[ ! "${LSMOD}" ]] && modprobe overlay

# create new Upper/Work Directories if they don't exist
[[ ! -z "${UPPERDIR}" ]] && mkdir -p "${UPPERDIR}"
[[ ! -z "${WORKDIR}" ]] && mkdir -p "${WORKDIR}"

# check we don't already have a mount in place, if not go for it
if [[ ! "${MOUNT}" ]]; then
  # mount new directory over the top of original NAS Share with overlayfs, so we only store the differences
  mount -t overlay -o lowerdir="${LOWERDIR}",upperdir="${UPPERDIR}",workdir="${WORKDIR}" overlayfs "${UPPERDIR}"

  # rsync from latest to our local (delete missing/removed files, as we're using overlayfs they remain in the original directory)
  rsync -rvi --size-only --delete-before --log-file="${LOGFILE}" "rsync://${RSYNC_SERVER}:${NAS}${LATEST}/" "${UPPERDIR}/"
fi
