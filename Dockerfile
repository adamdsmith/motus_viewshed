FROM rocker/binder:4.3.0

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/rstudio
WORKDIR /home/rstudio

USER root

COPY . /home/rstudio
RUN chown -R rstudio:rstudio /home/rstudio

RUN echo "Checking for 'apt.txt'..." \
 && if test -f "apt.txt" ; then \
      apt-get update --fix-missing > /dev/null \
      && xargs -a apt.txt apt-get install --yes \
      && apt-get clean > /dev/null \
      && rm -rf /var/lib/apt/lists/* ; \
    fi

USER rstudio

RUN if [ -f install.R ]; then Rscript install.R; fi