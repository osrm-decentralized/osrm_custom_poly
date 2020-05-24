#!/bin/bash

# 14.5.2020
# OSRM using pre-made .pbf's from https://server.nikhilvj.co.in/dump/ or other source

# check if .poly is available
ls -lrt /data/

if [ ! -f "${POLYFILE}" ]
then
    echo "${POLYFILE} not found. Exiting"
	exit 1
fi

# bring in environment variables
# var=${DEPLOY_ENV:-default_value} - from https://stackoverflow.com/a/39296572/4355695
OSMPBF=${PBFURL:-https://server.nikhilvj.co.in/dump/chennai.pbf}
profile=${PROFILE:-/profiles/car-modified.lua}

# downloading OSM data from URL. Saves as area.pbf for simplicity in later commands.
cd /data/
wget -N --timeout=20 ${OSMPBF}
bigpbf="${OSMPBF##*/}"
# first arg: get just the last part of the URL - the original pbf filename. from https://unix.stackexchange.com/questions/325490/how-to-get-last-part-of-http-link-in-bash#325492
# this is done to let the wget -N command work where it skips download if existing file is not older than one on server.

# clip pbf to .poly extents
echo "$(date): Starting osmconvert to clip ${bigpbf} to ${POLYFILE} extents"
osmconvert "/data/${bigpbf}" -B="${POLYFILE}" --complete-ways -o="/data/area.pbf"

echo "$(date): Created smaller pbf using ${POLYFILE}"
ls -lrt /data/

# compiling commands of OSRM - builds the graph
echo "$(date): Building OSRM graph"
osrm-extract -p ${profile} /data/area.pbf
osrm-partition /data/area.osrm
osrm-customize /data/area.osrm
echo "$(date): Done buildng OSRM graph"

# list all files created in compile
ls -lS /data/

# setting env variable DISABLE_ACCESS_LOGGING=1 for improving performance
DISABLE_ACCESS_LOGGING=1
export DISABLE_ACCESS_LOGGING

echo "$(date): Launching OSRM API server"
# launch OSRM-backend API
osrm-routed --algorithm mld /data/area.osrm
