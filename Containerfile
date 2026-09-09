FROM quay.io/fedora-ostree-desktops/kinoite@sha256:92ab91b3fbdd0f3e6e56d72c7503e73d7ac707579b61138fb2a87dec46a6613c AS builder

RUN KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    dnf5 -y install \
    curl \
    wget \
    git \
    make \
    gcc \
    patch \
    xz \
    cpio \
    kernel-devel-${KERNEL_VERSION} &&\
    dnf5 -y clean all

RUN ln -sf /bin/true /usr/bin/depmod

WORKDIR /src/snd_hda_macbookpro
RUN git clone https://github.com/davidjo/snd_hda_macbookpro.git ./ && \
    KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    ./install.cirrus.driver.sh -k ${KERNEL_VERSION} && \
    cp /src/snd_hda_macbookpro/build/hda/codecs/cirrus/snd-hda-codec-cs8409.ko /tmp/

WORKDIR /src/facetimehd-firmware
RUN git clone https://github.com/patjak/facetimehd-firmware.git ./ && \
    make && \
    cp /src/facetimehd-firmware/firmware.bin /tmp/

WORKDIR /src/facetimehd
RUN git clone https://github.com/patjak/facetimehd.git ./ && \
    KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    make -C /usr/lib/modules/${KERNEL_VERSION}/build M=$(pwd) modules && \
    cp /src/facetimehd/facetimehd.ko /tmp/

FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM quay.io/fedora-ostree-desktops/kinoite@sha256:92ab91b3fbdd0f3e6e56d72c7503e73d7ac707579b61138fb2a87dec46a6613c

RUN mkdir -p /usr/lib/modules-load.d /usr/lib/modprobe.d

COPY --from=builder /tmp/snd-hda-codec-cs8409.ko /tmp/
RUN KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    rm -f /usr/lib/modules/${KERNEL_VERSION}/kernel/sound/hda/codecs/cirrus/snd-hda-codec-cs8409.ko.xz && \
    mkdir -p /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    mv /tmp/snd-hda-codec-cs8409.ko /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    depmod -a -b /usr ${KERNEL_VERSION} && \
    echo "snd-hda-codec-cs8409" > /usr/lib/modules-load.d/apple-audio.conf

COPY --from=builder /tmp/firmware.bin /tmp/firmware.bin
RUN mkdir -p /usr/lib/firmware/facetimehd && \
    mv /tmp/firmware.bin /usr/lib/firmware/facetimehd/firmware.bin

COPY --from=builder /tmp/facetimehd.ko /tmp/facetimehd.ko
RUN KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    mkdir -p /usr/lib/modules/${KERNEL_VERSION}/extra/facetimehd && \
    mv /tmp/facetimehd.ko /usr/lib/modules/${KERNEL_VERSION}/extra/facetimehd && \
    depmod -a -b /usr ${KERNEL_VERSION} && \
    echo "facetimehd" > /usr/lib/modules-load.d/facetimehd.conf && \
    echo "blacklist bdc_pci" > /usr/lib/modprobe.d/blacklist-bdc_pci.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
