#
# Container Image BIND
#

FROM alpine:3.16.2

ARG PROJ_NAME
ARG PROJ_VERSION
ARG PROJ_BUILD_NUM
ARG PROJ_BUILD_DATE
ARG PROJ_REPO

LABEL org.opencontainers.image.authors="V10 Solutions"
LABEL org.opencontainers.image.title="${PROJ_NAME}"
LABEL org.opencontainers.image.version="${PROJ_VERSION}"
LABEL org.opencontainers.image.revision="${PROJ_BUILD_NUM}"
LABEL org.opencontainers.image.created="${PROJ_BUILD_DATE}"
LABEL org.opencontainers.image.description="Container image for BIND"
LABEL org.opencontainers.image.source="${PROJ_REPO}"

RUN apk update \
	&& apk add --no-cache "shadow" "bash" \
	&& usermod -s "$(command -v "bash")" "root"

SHELL [ \
	"bash", \
	"--noprofile", \
	"--norc", \
	"-o", "errexit", \
	"-o", "nounset", \
	"-o", "pipefail", \
	"-c" \
]

ENV LANG "C.UTF-8"
ENV LC_ALL "${LANG}"
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:/usr/local/lib/bind"

RUN apk add --no-cache \
	"ca-certificates" \
	"curl" \
	"krb5-dev" \
	"zlib-dev" \
	"fstrm-dev" \
	"libuv-dev" \
	"json-c-dev" \
	"openssl-dev" \
	"nghttp2-dev" \
	"libidn2-dev" \
	"libxml2-dev" \
	"libxslt-dev" \
	"python3-dev" \
	"readline-dev" \
	"protobuf-c-dev" \
	"libmaxminddb-dev"

RUN apk add --no-cache -t "build-deps" \
	"make" \
	"patch" \
	"linux-headers" \
	"gcc" \
	"g++" \
	"pkgconf" \
	"perl" \
	"python3" \
	"py3-ply"

RUN groupadd -r -g "480" "bind" \
	&& useradd \
		-r \
		-m \
		-s "$(command -v "nologin")" \
		-g "bind" \
		-c "BIND" \
		-u "480" \
		"bind"

WORKDIR "/tmp"

COPY "patches" "patches"

RUN curl -L -f -o "bind.tar.xz" "https://downloads.isc.org/isc/bind9/${PROJ_VERSION}/bind-${PROJ_VERSION}.tar.xz" \
	&& mkdir "bind" \
	&& tar -x -f "bind.tar.xz" -C "bind" --strip-components "1" \
	&& pushd "bind" \
	&& find "../patches" \
		-mindepth "1" \
		-type "f" \
		-iname "*.patch" \
		-exec bash --noprofile --norc -c "patch -p \"1\" < \"{}\"" ";" \
	&& ./configure \
		--prefix="/usr/local" \
		--libdir="/usr/local/lib/bind" \
		--libexecdir="/usr/local/libexec/bind" \
		--sysconfdir="/usr/local/etc/bind" \
		--datarootdir="/usr/local/share/bind" \
		--sharedstatedir="/usr/local/com/bind" \
		--runstatedir="/usr/local/var/run/bind" \
		--with-zlib \
		--with-gssapi \
		--with-json-c \
		--with-libxml2 \
		--with-openssl \
		--with-libidn2 \
		--with-readline \
		--with-maxminddb \
		--with-libnghttp2 \
		--disable-linux-caps \
		--disable-maintainer-mode \
		--enable-geoip \
		--enable-dnstap \
		--enable-shared \
		--enable-largefile \
	&& make \
	&& make "install" \
	&& ldconfig "${LD_LIBRARY_PATH}" \
	&& popd \
	&& rm -r -f "bind" \
	&& rm "bind.tar.xz" \
	&& rm -r -f "patches"

WORKDIR "/usr/local"

RUN mkdir -p "etc/bind" "lib/bind" "libexec/bind" "share/bind" \
	&& folders=("com/bind" "var/lib/bind" "var/run/bind") \
	&& for folder in "${folders[@]}"; do \
		mkdir -p "${folder}" \
		&& chmod "700" "${folder}" \
		&& chown -R "480":"480" "${folder}"; \
	done

WORKDIR "/"

RUN apk del "build-deps"
