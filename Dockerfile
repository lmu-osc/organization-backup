# Use an official R image as the base image
FROM rocker/r-ver:4.4.3

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
RUN echo "0 0 1 * * Rscript /archiving_code/backup_all_repos.R" > /etc/cron.d/run_r_script_monthly

# Apply correct permissions to the cron file
RUN chmod 0644 /etc/cron.d/run_r_script_monthly

# Ensure the cron service runs when the container starts
CMD ["cron", "-f"]
