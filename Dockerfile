FROM rocker/shiny:4.6.1

USER root

WORKDIR /app

# DBI is lightweight. Use a prebuilt Linux binary for DuckDB so the
# OpenShift build does not spend ages compiling DuckDB from source.
RUN R -q -e 'install.packages("DBI", repos="https://cloud.r-project.org"); \
    options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), R.version["platform"])); \
    install.packages("duckdb", repos="https://p3m.dev/cran/__linux__/manylinux_2_28/latest/")'

COPY . /app

# Build the UniMorph database once, when OpenShift builds the image.
RUN Rscript --vanilla R/setup_local_database.R && \
    chgrp -R 0 /app && \
    chmod -R g=u /app

# OpenShift-compatible writable home directory
ENV HOME=/tmp

EXPOSE 8080

CMD ["R", "--vanilla", "-e", "shiny::runApp('/app', host='0.0.0.0', port=8080)"]
