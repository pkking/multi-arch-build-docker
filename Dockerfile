FROM ubuntu


WORKDIR /workspace
ENV DEBIAN_FRONTEND=noninteractive

# Install development tools and utilities
RUN apt-get update -y && apt upgrade -y && apt-get install -y \
    build-essential \
    cmake \
    vim \
    wget \
    curl \
    net-tools \
    zlib1g-dev \
    lld \
    clang \
    locales \
    ccache \
    openssl \
    libssl-dev \
    pkg-config \
    ca-certificates \
    protobuf-compiler \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates \
    && locale-gen en_US.UTF-8


ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PATH="/root/.cargo/bin:${PATH}"

RUN pip install $MEMFABRIC_URL --no-cache-dir

RUN pip install setuptools-rust wheel build --no-cache-dir

# install rustup from rustup.rs
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustc --version && cargo --version && protoc --version

# Install SGLang
RUN git clone https://github.com/sgl-project/sglang
RUN (cd sglang/python && pip install -v .[srt_npu] --no-cache-dir) \
    && (cd sglang/sgl-router && python -m build && pip install --force-reinstall dist/*.whl) \
    && rm -rf sglang

CMD ["/bin/bash"]
