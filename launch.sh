#!/bin/bash

# 14.5.2020
# OSRM using custom .poly shape applied to pre-made .pbf's from https://server.nikhilvj.co.in/dump/ or other source

# Updated on 2.4.2021

# bring in environment variables
PBF_URL=${PBF_URL:-https://download.geofabrik.de/asia/india-latest.osm.pbf}

MAX_MATCHING_SIZE=${MAX_MATCHING_SIZE:--1}

MAX_TABLE_SIZE=${MAX_TABLE_SIZE:-1000}

PROFILE=${PROFILE:-car-modified.lua}

BUILD=${BUILD:-N}

if [ "$BUILD" == "Y" ] 
then
    echo "$(date +"%Y-%m-%d %H:%M:%S"): BUILD = Y"

    if [ ! -f "${POLYFILE}" ]
    then
        echo "${POLYFILE} not found. Exiting"
        exit 1
    fi

    # make a folder in PV
    mkdir -p "/data/osm_pbf/"
    # go to folder in persistent storage volume
    cd "/data/osm_pbf/"

    # download .pbf if newer
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Downloading ${PBF_URL} if newer"
    wget -N -q --timeout=20 ${PBF_URL}

    # change to /data folder : this should be mounted persistent volume
    cd /data

    # cutting down by bounds
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Starting osmconvert to clip to shape.poly"
    # osmconvert bigarea.pbf -B="/app/${POLYFILE}" --complete-ways -o=area.pbf
    osmconvert "osm_pbf/${PBF_URL##*/}" -B="${POLYFILE}" --complete-ways -o=area.pbf

    # compiling commands of OSRM - builds the graph
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Running osrm-extract"
    osrm-extract -p "/app/profiles/${PROFILE}" area.pbf
    ls -lS --block-size=M

    echo "$(date +"%Y-%m-%d %H:%M:%S"): Running osrm-partition"
    osrm-partition area.osrm
    ls -lS --block-size=M

    echo "$(date +"%Y-%m-%d %H:%M:%S"): Running osrm-customize"
    osrm-customize area.osrm

    echo "$(date +"%Y-%m-%d %H:%M:%S"): Done building osrm graph"

else
    echo "$(date +"%Y-%m-%d %H:%M:%S"): Skipping build process as BUILD = N"

fi

# launch OSRM-backend API
cd /data
ls -lS --block-size=M

# setting env variable DISABLE_ACCESS_LOGGING=1 for improving performance
export DISABLE_ACCESS_LOGGING=1

echo "$(date +"%Y-%m-%d %H:%M:%S"): Launching osrm-routed, default port 5000"
osrm-routed --algorithm mld --max-matching-size=${MAX_MATCHING_SIZE} --max-table-size=${MAX_TABLE_SIZE} area.osrm
