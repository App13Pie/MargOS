FROM quay.io/fedora/fedora-bootc@sha256:498d7b7816044c3ef854a450c1b6873f48a870adc938c5cefa426a55a05a9bb3 AS builder

RUN KERNEL_VERSION="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" && \
    dnf5 -y install \
        wget \
        git \
        gcc \
        make \
        patch \
        kernel-devel-${KERNEL_VERSION} &&\
    dnf5 -y clean all

WORKDIR /src
RUN git clone https://github.com/davidjo/snd_hda_macbookpro.git ./

RUN KERNEL_VERSION="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" && \
    make -C /usr/lib/modules/${KERNEL_VERSION}/build M=$(pwd) modules && \
    cp /usr/lib/modules/${KERNEL_VERSION}/kernel/sound/hda/codecs/cirrus/snd-hda-codec-cs8409.ko.xz /tmp/

FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM quay.io/fedora-ostree-desktops/kinoite@sha256:f5f7b33ed9b5e747482ece8f089d7021c3404bfac8649be7fea32c9eee1602c9

# Audio Driver
COPY --from=builder /tmp/snd-hda-codec-cs8409.ko.xz /tmp/

RUN KERNEL_VERSION="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" && \
    mkdir -p /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    mv /tmp/snd-hda-codec-cs8409.ko.xz /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    depmod -a -b /usr ${KERNEL_VERSION}

RUN mkdir -p /usr/lib/modules-load.d /usr/lib/modprobe.d && \
    echo "snd-hda-codec-cs8409" > /usr/lib/modules-load.d/apple-audio.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
