# Builds and runs both layers of the project in one image:
#   core/   the COBOL "mainframe", compiled with GNU COBOL (gnucobol3)
#   client/ the Flask web client, served by gunicorn
#
# core/data/ (the indexed .dat files) is NOT baked into the image — it is
# bind-mounted at runtime via docker-compose.yml so data survives rebuilds
# when core/ gets updated.

# ---- Stage 1: compile the COBOL core -------------------------------------
FROM debian:bookworm-slim AS cobol-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        gnucobol3 \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/core
COPY core/Makefile ./Makefile
COPY core/src ./src

RUN make build

# ---- Stage 2: runtime (Flask client + compiled bank_api binary) ----------
FROM python:3.12-slim-bookworm AS runtime

# libcob4 is the GnuCOBOL runtime library the compiled binary is linked
# against; the compiler toolchain itself isn't needed here.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcob4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY client/requirements.txt client/requirements.txt
RUN pip install --no-cache-dir -r client/requirements.txt

COPY client client
COPY --from=cobol-builder /build/core/bin/bank_api /app/core/bin/bank_api

# Mount point for the bind-mounted data volume (see docker-compose.yml).
RUN mkdir -p /app/core/data

EXPOSE 5005

WORKDIR /app/client
CMD ["gunicorn", "--workers", "3", "--bind", "0.0.0.0:5005", "wsgi:app"]
