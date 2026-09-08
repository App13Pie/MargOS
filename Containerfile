FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM quay.io/fedora-ostree-desktops/kinoite@sha256:f5f7b33ed9b5e747482ece8f089d7021c3404bfac8649be7fea32c9eee1602c9

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
