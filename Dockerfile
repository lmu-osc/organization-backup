# Use an official R image as the base image
FROM rocker/r-ver:4.4.3

# Add a label to the Dockerfile for auto tagging of builds
LABEL version="1.1.0" \
      description="GitHub Organization backup code"

# Copy your R script to the container
COPY . /archiving_code

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
RUN R -e "install.packages('renv'); renv::restore('archiving_code')"

# Set up a cron job to run the R script every month (e.g., the 1st day of every month at midnight)
RUN touch /var/log/cron.log \
    && echo "0 0 * * 0 Rscript /archiving_code/backup_all_repos.R >> /var/log/cron.log 2>&1" > cron_jobs_script \
    && echo "0 0 * * 0 Rscript /archiving_code/remove_old_backups.R >> /var/log/cron.log 2>&1" >> cron_jobs_script \
    && crontab cron_jobs_script \
    && rm cron_jobs_script


# Ensure the cron service runs when the container starts
CMD ["cron", "&&", "tail", "-f", "/var/log/cron.log"]
