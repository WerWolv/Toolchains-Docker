FROM ubuntu:22.04 AS toolchain-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    autoconf \
    automake \
    bison \
    flex \
    gawk \
    help2man \
    libncurses5-dev \
    libtool-bin \
    texinfo \
    unzip \
    wget \
    xz-utils \
    python3 \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone https://github.com/crosstool-ng/crosstool-ng.git && \
    cd crosstool-ng && \
    ./bootstrap && \
    ./configure --prefix=/opt/crosstool-ng && \
    make && \
    make install

ENV PATH="/opt/crosstool-ng/bin:${PATH}"

WORKDIR /crosstool-build

ARG TOOLCHAIN_TRIPLE

RUN mkdir -p touch samples/toolchains-docker && touch samples/toolchains-docker/reported.by
COPY toolchains/${TOOLCHAIN_TRIPLE}.config samples/toolchains-docker/crosstool.config

RUN useradd -m -s /bin/bash ctng && \
    mkdir -p /crosstool-build /opt/x-tools && \
    chown -R ctng:ctng /crosstool-build /opt/x-tools

USER ctng

RUN ct-ng toolchains-docker && \
    ct-ng build CT_PREFIX=/opt/x-tools

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    gdb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolchain-builder /opt/x-tools /opt/x-tools

ENV PATH="/opt/x-tools/bin:${PATH}"

WORKDIR /workspace

CMD ["/bin/bash"]