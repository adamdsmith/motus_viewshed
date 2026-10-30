FROM rocker/binder:4.4.2

ENV DEBIAN_FRONTEND=noninteractive
ENV CARTO_API_KEY=cb1_4ygs_1_a9ef5288fe01263193c16276
ENV HOME=/home/rstudio
WORKDIR /home/rstudio

USER root

COPY . /home/rstudio
RUN chown -R rstudio:rstudio /home/rstudio

# Expose the existing CARTO key to RStudio sessions
RUN printf 'CARTO_API_KEY=%s\n' "$CARTO_API_KEY" \
    > /home/rstudio/.Renviron \
 && chown rstudio:rstudio /home/rstudio/.Renviron

RUN echo "Checking for 'apt.txt'..." \
 && if test -f "apt.txt" ; then \
      apt-get update --fix-missing > /dev/null \
      && xargs -a apt.txt apt-get install --yes \
      && apt-get clean > /dev/null \
      && rm -rf /var/lib/apt/lists/* ; \
    fi

USER rstudio

RUN if [ -f install.R ]; then Rscript install.R; fi
