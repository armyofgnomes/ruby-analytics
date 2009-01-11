#!/usr/bin/env bash
# Usage: iis_to_ncsa.sh log_folder site_name-Mon-YYYY
# rconvlog-linux must be in same directory
LOGDIR="logs"
cat $1/* > $LOGDIR/$2
./rconvlog-linux $LOGDIR/$2
mv $2.ncsa $LOGDIR/$2
gzip $LOGDIR/$2
