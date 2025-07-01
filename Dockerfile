FROM perl:slim

LABEL maintainer="Rusty Bower" \
      org.opencontainers.image.title="pisg" \
      org.opencontainers.image.description="Perl IRC Stats Generator" \
      org.opencontainers.image.version="latest" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.source="https://github.com/rustybower/pisg"

# Install required system packages and CPAN modules
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libtext-iconv-perl \
        libstorable-perl \
        liblocale-gettext-perl \
        libtext-charwidth-perl \
        libtext-wrapi18n-perl \
        libhtml-parser-perl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/pisg

COPY . .

VOLUME /cache /config /logs /nginx

CMD ["./pisg", "-co", "/config/pisg.cfg", "-o", "/nginx/index.html"]

