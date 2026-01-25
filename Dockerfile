FROM ubuntu:24.04 AS toolchain-builder

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

RUN useradd -m -s /bin/bash ctng && \
    mkdir -p /crosstool-build /opt/x-tools && \
    chown -R ctng:ctng /crosstool-build /opt/x-tools

USER ctng

WORKDIR /crosstool-build

ARG TOOLCHAIN_TRIPLE

COPY --chown=ctng:ctng toolchains/${TOOLCHAIN_TRIPLE}.config .config

RUN ct-ng oldconfig && \
    (sed -i 's/^CT_LOG_PROGRESS_BAR=.*/CT_LOG_PROGRESS_BAR=n/' .config || echo "CT_LOG_PROGRESS_BAR=n" >> .config) && \
    (sed -i 's/^CT_PREFIX_DIR=.*/CT_PREFIX_DIR="\/opt\/x-tools\/"/' .config || echo "CT_PREFIX_DIR=\"/opt/x-tools/\"" >> .config) && \
    (sed -i 's/^CT_GLIBC_ENABLE_DEBUG=.*/CT_GLIBC_ENABLE_DEBUG=n/' .config || echo "CT_GLIBC_ENABLE_DEBUG=n" >> .config) && \
    ct-ng build CT_PREFIX=/opt/x-tools || \
    (cat build.log && exit 1)

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
