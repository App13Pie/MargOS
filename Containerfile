FROM quay.io/fedora-ostree-desktops/kinoite@sha256:e8b217bcb4db3e54537562bcfdaaea8597fc7a4561aba5e2980bda40a14fe11a AS builder

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

FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM quay.io/fedora-ostree-desktops/kinoite@sha256:e8b217bcb4db3e54537562bcfdaaea8597fc7a4561aba5e2980bda40a14fe11a

RUN mkdir -p /usr/lib/modules-load.d /usr/lib/modprobe.d

COPY --from=builder /tmp/snd-hda-codec-cs8409.ko /tmp/
RUN KERNEL_VERSION="$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-core | tail -n 1)" && \
    rm -f /usr/lib/modules/${KERNEL_VERSION}/kernel/sound/hda/codecs/cirrus/snd-hda-codec-cs8409.ko.xz && \
    mkdir -p /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    mv /tmp/snd-hda-codec-cs8409.ko /usr/lib/modules/${KERNEL_VERSION}/extra/ && \
    depmod -a -b /usr ${KERNEL_VERSION} && \
    echo "snd-hda-codec-cs8409" > /usr/lib/modules-load.d/apple-audio.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
