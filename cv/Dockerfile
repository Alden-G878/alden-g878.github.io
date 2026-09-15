# Pinned toolchain for cv/build.sh — TeX Live + pandoc + poppler, in one image.
#
#   docker build -t cv-tex:local cv/
#
# Why a Dockerfile instead of installing at run time: the old recipe ran
# `apt-get update && apt-get install texlive-*` on EVERY invocation. That was
# ~26 s of the ~30 s build — repeated locally on every edit and, worse, on every
# CI push (runners have no Docker layer cache). Baking it here moves that cost
# to a one-time image build (~45 s) and makes each run ~0.5 s.
#
# Build context is cv/ (see build.sh), so this file and warmup.tex are the only
# inputs. Everything is pinned: Ubuntu base by tag, pandoc by version AND
# sha256, TeX by the distro's fixed package set.

FROM ubuntu:24.04

# Set by BuildKit automatically ("amd64" / "arm64"), so the pandoc download
# below resolves per-architecture without the caller passing anything.
ARG TARGETARCH

# texlive-latex-base + -recommended is exactly what cv.tex needs (fontenc,
# inputenc, geometry, hyperref, microtype); -fonts-recommended supplies the
# EC/LModern fonts used under T1 encoding.
#
# --no-install-recommends is load-bearing: the default recommends pull in
# texlive-latex-extra and ~1.4 GB of documentation/dependency weight that this
# document does not use.
#
# poppler-utils (pdftotext) is here so the text-layer regression check can run
# inside the container on a host that has no poppler — which is most of them,
# and is the case on GitHub's runners too.
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      texlive-latex-base \
      texlive-latex-recommended \
      texlive-fonts-recommended \
      poppler-utils \
      curl \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# pandoc, pinned to the exact version cv/build.sh's committed HTML was produced
# with. A floating version would silently rewrite _includes/cv-live.html and turn
# the CI drift check red for no reason.
#
# NOTE: pandoc's official `pandoc/core` Docker image is Alpine/musl-based, so its
# 157 MB binary CANNOT be copied into this glibc image — it fails at exec with
# "no such file or directory" because ld-musl-x86_64.so.1 is absent. Use the
# release .deb (glibc) as below, never `COPY --from=pandoc/core`.
#
# The sha256 is checked, so a compromised or truncated download fails the build
# rather than shipping a different parser.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) sha="89d4c9d97818c62a97157f0072844e4602c6cee795bf84abd1aee7273abcda99" ;; \
      arm64) sha="d03e1be90fa510aaddc9b1e17f3e4615de0ab8a0aa7e7553502a3c9701887730" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/pandoc.deb \
      "https://github.com/jgm/pandoc/releases/download/3.11/pandoc-3.11-1-${TARGETARCH}.deb"; \
    echo "${sha}  /tmp/pandoc.deb" | sha256sum -c -; \
    dpkg -i /tmp/pandoc.deb; \
    rm -f /tmp/pandoc.deb

# Compile a scratch document at build time to bake the EC/LModern PK fonts and
# the LaTeX format files into the image. Without this, every run spends ~1.5 s
# regenerating them via mktexpk (measured: 2.0 s/run vs 0.44 s/run).
#
# IMPORTANT: the font cache lands under root's HOME (/root/.texlive2023/...), so
# the PDF step in build.sh must NOT pass `-e HOME=...`. Passing HOME=/tmp moves
# texmf-var elsewhere and silently defeats this warm-up — a real trap that was
# hit while measuring. The HTML step does pass HOME=/tmp, which is fine because
# pandoc writes nothing there.
#
# Failure here should fail the build: it means the Dockerfile is wrong, and
# silently skipping it would just restore the slow path with no explanation.
COPY warmup.tex /tmp/warmup.tex
RUN cd /tmp \
 && pdflatex -interaction=nonstopmode -halt-on-error warmup.tex >/dev/null \
 && test -f /tmp/warmup.pdf \
 && rm -f /tmp/warmup.*

WORKDIR /work
