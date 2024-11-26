#!/bin/sh
set -e

if [ "$IMGBASE" = "" ]
then
  echo "FATAL: IMGBASE is not set"
  exit 1
fi

VER=$1
case "$VER" in
  5.0|4.1|4.0)
    echo "Building image for Cassandra $VER"
  ;;
  *)
    echo "Unknown or unsupported Cassandra version $VER"
    exit 1
  ;;
esac
ARCH=${2:-amd64}

# Build our own Cassandra base image or use the offical one
if [ -d cassandra/$VER ]
then
  (cd cassandra/$VER && docker build -t=cassandra:${VER} .)
else
  docker pull cassandra:$VER
fi

TMPFILE=Dockerfile-$VER
sed "s/{{CASSANDRA_VER}}/$VER/g" <Dockerfile-template >$TMPFILE
docker build -t="$IMGBASE:${VER}-${ARCH}" -f $TMPFILE .
rm -f $TMPFILE
