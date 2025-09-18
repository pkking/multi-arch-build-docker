ARG CANN_VERSION=8.2.rc1
ARG DEVICE_TYPE=910b  # Default, overridden by workflow
ARG OS=ubuntu22.04
ARG PYTHON_VERSION=py3.11
ARG REGISTRY=quay.io/ascend

FROM $REGISTRY/cann:$CANN_VERSION-$DEVICE_TYPE-$OS-$PYTHON_VERSION

# Define environments
ARG TARGETARCH # auto-set by Buildx (amd64/arm64)
ARG PIP_INDEX_URL="https://pypi.org/simple/"
ARG APTMIRROR=""
ARG PYTORCH_VERSION=2.6.0
ARG TORCHVISION_VERSION=0.21.0
ARG VLLM_TAG=v0.8.5
ARG SGLANG_TAG=main
ARG ASCEND_CANN_PATH=/usr/local/Ascend/ascend-toolkit
ARG SGLANG_KERNEL_NPU_TAG=main

# Set environment variables according to architecture
ARG MEMFABRIC_URL_AMD64="https://sglang-ascend.obs.cn-east-3.myhuaweicloud.com/sglang/mf_adapter-1.0.0-cp311-cp311-linux_x86_64.whl"
ARG PTA_URL_AMD64="https://gitcode.com/Ascend/pytorch/releases/download/v7.1.0.2-pytorch2.6.0/torch_npu-2.6.0.post2-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
ARG TRITON_ASCEND_URL_AMD64="https://sglang-ascend.obs.cn-east-3.myhuaweicloud.com/sglang/triton_ascend-3.2.0.dev20250815-cp311-cp311-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"

ARG MEMFABRIC_URL_ARM64="https://sglang-ascend.obs.cn-east-3.myhuaweicloud.com/sglang/mf_adapter-1.0.0-cp311-cp311-linux_aarch64.whl"
ARG PTA_URL_ARM64="https://gitee.com/ascend/pytorch/releases/download/v7.1.0.1-pytorch2.6.0/torch_npu-2.6.0.post1-cp311-cp311-manylinux_2_28_aarch64.whl"
ARG TRITON_ASCEND_URL_ARM64="https://sglang-ascend.obs.cn-east-3.myhuaweicloud.com/sglang/triton_ascend-3.2.0.dev20250729-cp311-cp311-manylinux_2_27_aarch64.manylinux_2_28_aarch64.whl"

RUN if [ "$TARGETARCH" = "amd64" ]; then \
      echo "Using x86_64 dependencies"; \
      echo "MEMFABRIC_URL=$MEMFABRIC_URL_AMD64" >> /etc/environment_new; \
      echo "PTA_URL=$PTA_URL_AMD64" >> /etc/environment_new; \
      echo "TRITON_ASCEND_URL=$TRITON_ASCEND_URL_AMD64" >> /etc/environment_new; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      echo "Using aarch64 dependencies"; \
      echo "MEMFABRIC_URL=$MEMFABRIC_URL_ARM64" >> /etc/environment_new; \
      echo "PTA_URL=$PTA_URL_ARM64" >> /etc/environment_new; \
      echo "TRITON_ASCEND_URL=$TRITON_ASCEND_URL_ARM64" >> /etc/environment_new; \
    else \
      echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1; \
    fi

WORKDIR /workspace
ENV DEBIAN_FRONTEND=noninteractive

# Update pip & apt sources
RUN pip config set global.index-url $PIP_INDEX_URL && \
    if [ -n "$APTMIRROR" ]; then sed -i "s|//.*.ubuntu.com|//$APTMIRROR|g" /etc/apt/sources.list; fi

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

RUN . /etc/environment_new && \
    pip install $MEMFABRIC_URL --no-cache-dir

RUN pip install setuptools-rust wheel build --no-cache-dir

# install rustup from rustup.rs
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustc --version && cargo --version && protoc --version

# Install SGLang
RUN mkdir /workspace/sglang
COPY . /workspace/sglang
RUN (cd sglang/python && pip install -v .[srt_npu] --no-cache-dir) \
    && (cd sglang/sgl-router && python -m build && pip install --force-reinstall dist/*.whl) \
    && rm -rf sglang

CMD ["/bin/bash"]
