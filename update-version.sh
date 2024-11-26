#!/bin/sh -e

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

if [ -d cassandra/$VER ]
then
  VERSION=$(curl -L https://raw.githubusercontent.com/docker-library/cassandra/refs/heads/master/${VER}/Dockerfile | grep "ENV CASSANDRA_VERSION")
  SHA=$(curl -L https://raw.githubusercontent.com/docker-library/cassandra/refs/heads/master/${VER}/Dockerfile | grep "ENV CASSANDRA_SHA512")
  sed -i .bak "s/^ENV CASSANDRA_VERSION.*/$VERSION/" cassandra/${VER}/Dockerfile
  sed -i .bak "s/^ENV CASSANDRA_SHA512.*/$SHA/" cassandra/${VER}/Dockerfile
  rm -f cassandra/${VER}/*.bak
fi
