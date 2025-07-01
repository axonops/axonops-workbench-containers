#!/bin/bash

# Run the provided command if it is not "cassandra" (optionally with arguments)
if [ "$1" != "cassandra" ]
then
  exec "$@"
  exit $?
fi

if [ "$CASSANDRA_NATIVE_TRANSPORT_PORT" != "" ]
then
  sed -i "s/^native_transport_port:.*$/native_transport_port: $CASSANDRA_NATIVE_TRANSPORT_PORT/" "$CASSANDRA_CONF/cassandra.yaml"
fi

touch /var/log/axonops/axon-agent.log
chown axonops:axonops /var/log/axonops/axon-agent.log
if [ -f /usr/share/axonops/axonops-jvm.options ]; then
  echo ". /usr/share/axonops/axonops-jvm.options" >> $CASSANDRA_CONF/cassandra-env.sh
fi
su axonops -c "/usr/share/axonops/axon-agent $AXON_AGENT_ARGS" &

exec /usr/local/bin/docker-entrypoint.sh "$@"
