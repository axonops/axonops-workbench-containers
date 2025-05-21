#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM eclipse-temurin:17-jre-jammy

# explicitly set user/group IDs
RUN set -eux; \
	groupadd -r cassandra --gid=999; \
	useradd -r -g cassandra --uid=999 cassandra

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# solves warning: "jemalloc shared library could not be preloaded to speed up memory allocations"
		libjemalloc2 \
# "free" is used by cassandra-env.sh
		procps \
# "cqlsh" needs a python interpreter
		python3 \
# "ip" is not required by Cassandra itself, but is commonly used in scripting Cassandra's configuration (since it is so fixated on explicit IP addresses)
		iproute2 \
# Cassandra will automatically use numactl if available
#   https://github.com/apache/cassandra/blob/18bcda2d4c2eba7370a0b21f33eed37cb730bbb3/bin/cassandra#L90-L100
#   https://github.com/apache/cassandra/commit/604c0e87dc67fa65f6904ef9a98a029c9f2f865a
		numactl \
	; \
	rm -rf /var/lib/apt/lists/*; \
# https://issues.apache.org/jira/browse/CASSANDRA-15767 ("bin/cassandra" only looks for "libjemalloc.so" or "libjemalloc.so.1" which doesn't match our "libjemalloc.so.2")
	libjemalloc="$(readlink -e /usr/lib/*/libjemalloc.so.2)"; \
	ln -sT "$libjemalloc" /usr/local/lib/libjemalloc.so; \
	ldconfig

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.17
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates gnupg wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

ENV CASSANDRA_HOME /opt/cassandra
ENV CASSANDRA_CONF /etc/cassandra
ENV PATH $CASSANDRA_HOME/bin:$PATH

# https://cwiki.apache.org/confluence/display/CASSANDRA2/DebianPackaging#DebianPackaging-AddingRepositoryKeys
# $ docker run --rm buildpack-deps:bullseye-curl bash -c 'wget -qO- https://downloads.apache.org/cassandra/KEYS | gpg --batch --import &> /dev/null && gpg --batch --list-keys --with-fingerprint --with-colons' | awk -F: '$1 == "pub" && $2 == "-" { pub = 1 } pub && $1 == "fpr" { fpr = $10 } $1 == "sub" { pub = 0 } pub && fpr && $1 == "uid" && $2 == "-" { print "#", $10; print "\t" fpr " \\"; pub = 0 }'
ENV GPG_KEYS \
# Eric Evans <eevans@sym-link.com>
	CEC86BB4A0BA9D0F90397CAEF8358FA2F2833C93 \
# Eric Evans <eevans@sym-link.com>
	C4965EE9E3015D192CCCF2B6F758CE318D77295D \
# Sylvain Lebresne (pcmanus) <sylvain@datastax.com>
	5AED1BF378E9A19DADE1BCB34BD736A82B5C1B00 \
# T Jake Luciani <jake@apache.org>
	514A2AD631A57A16DD0047EC749D6EEC0353B12C \
# Michael Shuler <michael@pbandjelly.org>
	A26E528B271F19B9E5D8E19EA278B781FE4B2BDA \
# Michael Semb Wever <mick@thelastpickle.com>
	A4C465FEA0C552561A392A61E91335D77E3E87CB \
# Alex Petrov <oleksandr.petrov@gmail.com>
	9E66CEC6106D578D0B1EB9BFF1000962B7F6840C \
# Jordan West <jwest@apache.org>
	C4009872C59B49561310D966D0062876AF30F054 \
# Brandon Williams <brandonwilliams@apache.org>
	B7842CDAF36E6A3214FAE35D5E85B9AE0B84C041 \
# Ekaterina Buryanova Dimitrova (CODE SIGNING KEY) <e.dimitrova@gmail.com>
	3E9C876907A560ACA00964F363E9BAD215BBF5F0 \
# Sam Tunnicliffe (CODE SIGNING KEY) <samt@apache.org>
	F8B7FD00E05C932991A2CD6150EE103D162C5A55 \
# Stefan Miklosovic <smiklosovic@apache.org>
	7464AAD9068241C50BA6A26232F35CB2F546D93E \
# Berenguer Blasi (Code Signing Key) <bereng@apache.org>
	CEC5C50B9C629EF0F5AB2706650B72EB14CCD622

ENV CASSANDRA_VERSION 5.1-SNAPSHOT
ENV CASSANDRA_SHA512 51478b18b8bce82a6b4915f31470d031306724041a4f2b684fd17635f8a5a9802594c0bbc3d0154cfa52d87a253d7868636985787aa1e3e00136259302689363

RUN set -eux; \
	lastRelease=$(curl -s https://nightlies.apache.org/cassandra/Cassandra-trunk/ | grep img | grep DIR | cut -d= -f4 | awk -F '"' '{print $2}' | grep -v ^$ | sed 's$/$$g' | tail -1) \
	releaseBin="https://nightlies.apache.org/cassandra/Cassandra-trunk/${lastRelease}/artifacts/jdk17/amd64/apache-cassandra-5.1-SNAPSHOT-bin.tar.gz"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates gnupg wget; \
	rm -rf /var/lib/apt/lists/*; \
	curl -L $releaseBin -o cassandra-bin.tgz; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
	mkdir -p "$CASSANDRA_HOME"; \
	tar --extract --file cassandra-bin.tgz --directory "$CASSANDRA_HOME" --strip-components 1; \
	rm cassandra-bin.tgz*; \
	\
	[ ! -e "$CASSANDRA_CONF" ]; \
	mv "$CASSANDRA_HOME/conf" "$CASSANDRA_CONF"; \
	ln -sT "$CASSANDRA_CONF" "$CASSANDRA_HOME/conf"; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "$dpkgArch" in \
		ppc64el) \
# https://issues.apache.org/jira/browse/CASSANDRA-13345
# "The stack size specified is too small, Specify at least 328k"
			grep -- '^-Xss256k$' "$CASSANDRA_CONF/jvm-server.options"; \
			sed -ri 's/^-Xss256k$/-Xss512k/' "$CASSANDRA_CONF/jvm-server.options"; \
			grep -- '^-Xss512k$' "$CASSANDRA_CONF/jvm-server.options"; \
			;; \
	esac; \
	\
	mkdir -p "$CASSANDRA_CONF" /var/lib/cassandra /var/log/cassandra; \
	chown -R cassandra:cassandra "$CASSANDRA_CONF" /var/lib/cassandra /var/log/cassandra; \
	chmod 1777 "$CASSANDRA_CONF" /var/lib/cassandra /var/log/cassandra; \
	chmod -R a+rwX "$CASSANDRA_CONF"; \
	ln -sT /var/lib/cassandra "$CASSANDRA_HOME/data"; \
	ln -sT /var/log/cassandra "$CASSANDRA_HOME/logs"; \
	\
# smoke test
	cassandra -v

VOLUME /var/lib/cassandra

COPY docker-entrypoint.sh /usr/local/bin/

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160

ENV AXON_AGENT_LOG_OUTPUT=std
ENV MAJOR_VERSION=5.0
ENV AGENT_VER=5.0

# RUN groupadd --gid 9988 axonops && \
#     useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
#     usermod -aG axonops cassandra && \
#     apt-get -y update && apt-get -y install curl gnupg netcat-openbsd && \
#     curl https://packages.axonops.com/apt/repo-signing-key.gpg | apt-key add - && \
#     echo "deb https://packages.axonops.com/apt axonops-apt main" > /etc/apt/sources.list.d/axonops-apt.list && \
#     apt-get -y update && \
#     apt-get -y install axon-cassandra${AGENT_VER}-agent-jdk17 && \
#     apt-get -y clean && \
#     echo 'axon-agent:' > /etc/axonops/axon-agent.yml && \
#     chown cassandra:cassandra /etc/axonops/axon-agent.yml && \
#     chmod 0400 /etc/axonops/axon-agent.yml && \
#     touch /var/run/utmp

RUN groupadd --gid 9988 axonops 
RUN useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops 
RUN usermod -aG axonops cassandra 
RUN apt-get -y update && apt-get -y install curl gnupg netcat-openbsd 
RUN curl https://packages.axonops.com/apt/repo-signing-key.gpg | apt-key add - 
RUN echo "deb https://packages.axonops.com/apt axonops-apt main" > /etc/apt/sources.list.d/axonops-apt.list 
RUN apt-get -y update 
RUN apt-get -y install axon-cassandra${AGENT_VER}-agent-jdk17 
RUN apt-get -y clean 
RUN echo 'axon-agent:' > /etc/axonops/axon-agent.yml 
RUN chown cassandra:cassandra /etc/axonops/axon-agent.yml 
RUN chmod 0400 /etc/axonops/axon-agent.yml 
RUN touch /var/run/utmp


COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chown root:root /axonops-entrypoint.sh && chmod 0755 /axonops-entrypoint.sh

ENTRYPOINT ["/axonops-entrypoint.sh"]

CMD ["cassandra", "-f"]
