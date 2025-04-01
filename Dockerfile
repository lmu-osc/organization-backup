# Use an official R image as the base image
FROM rocker/r-ver:4.4.3

# Add a label to the Dockerfile for auto tagging of builds
LABEL version="1.0.0" \
      description="GitHub Organization backup code"

# Install dependencies
RUN apt-get update && apt-get install -y \
  cron \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  git \
  pandoc \
  && rm -rf /var/lib/apt/lists/*

# Bootstrap renv
RUN R -e "install.packages('renv')"

# Copy your R script to the container
COPY . /archiving_code

# Set up a cron job to run the R script every month (e.g., the 1st day of every month at midnight)
RUN touch /var/log/cron.log \
    && echo "0 0 1 * * Rscript /archiving_code/backup_all_repos.R" | crontab


# Ensure the cron service runs when the container starts
CMD ["cron", "&&", "tail", "-f", "/var/log/cron.log"]
