FROM rocker/shiny:4.6.1

USER root

WORKDIR /app

# Install DBI normally
RUN R -q -e 'install.packages("DBI", repos="https://cloud.r-project.org")'

# Install pre-built DuckDB binary for Linux.
# The full HTTPUserAgent is required by Posit Package Manager
# to select the correct Linux/R binary.
RUN R -q -e 'options(HTTPUserAgent = sprintf("R/%s R (%s)", \
    getRversion(), \
    paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"]))); \
    install.packages("duckdb", \
    repos="https://p3m.dev/cran/__linux__/manylinux_2_28/latest/"); \
    stopifnot(requireNamespace("duckdb", quietly=TRUE))'

COPY . /app

# Build UniMorph database into the image
RUN Rscript --vanilla R/setup_local_database.R && \
    chgrp -R 0 /app && \
    chmod -R g=u /app

ENV HOME=/tmp

EXPOSE 8080

CMD ["R", "--vanilla", "-e", "shiny::runApp('/app', host='0.0.0.0', port=8080)"]
