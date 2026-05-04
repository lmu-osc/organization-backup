
# LMU OSC Organization Backup

The code in this repo is intended to hit the GitHub API for all of our organization repos so that we can create backups of all of the code, pull requests, issues, and related metadata for all of our repos. This is mostly a worst-case, disaster back-up in case someone were to e.g. get access to our organization and delete all of the content online. Then, we would have local back-ups of our content also available.

The main script for this is `backup_all_repos.R`. It is intended to be run once a month to keep the back-ups up-to-date. The script will download all of the content of all of the repos in the organization and store them in a folder called `/archive/YYYY-MM`.

## Getting a Github Personal Access Token (PAT)

Both for the local run of the script `backup_all_repos.R` and the Docker approach, you need a Personal Access Token (PAT).

GitHub recommends using **fine-grained personal access tokens** for improved security and control. However, **classic tokens may be required** for organization-wide archival access, as fine-grained tokens have limitations for accessing multiple repositories across an organization at once.

### Option 1: Create a Fine-Grained Personal Access Token (Recommended)

If accessing a limited set of repositories, fine-grained tokens provide better security:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Fill in the token name (e.g., "GitHub Archiver")
4. Set an expiration date (recommended: 90 days or less)
5. Under "Resource owner", select your organization
6. Under "Repository access", select "All repositories" or specific repos to archive
7. Under "Permissions", grant the following:
   - Repository: `Contents` (read)
   - Repository: `Issues` (read)
   - Repository: `Pull requests` (read)
   - Organization: `Members` (read) - if needed for organization metadata
8. Click "Generate token" and save it securely

### Option 2: Create a Classic Personal Access Token

For full organization-wide access (recommended for complete backups), you'll need a classic token:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give your token a descriptive name (e.g., "GitHub Archiver")
4. Set an expiration date (recommended: 90 days or less)
5. Select the following scopes:
   - `admin:org` - for organization administration and metadata
   - `gist` - for gist access
   - `repo` - for repository access (includes private repo access)
   - `user` - for user profile information
   - `workflow` - for GitHub Actions workflow access
6. Click "Generate token" and save it securely

**⚠️ Important**: Treat your PAT like a password. Never commit it to version control or share it publicly. GitHub will automatically revoke tokens that haven't been used in a year.

## Run the backup script locally

If you run the script `backup_all_repos.R`, you need to put your PAT into your system environment. There are two approaches to this:

* Add it to the `~/.Renviron` file (restart R to take the changes into effect)
* Set it via `Sys.setenv(GITHUB_PAT = "ghp_...")`. The downloaded archive will be stored in the subfolder `./archive`.

**Note that if you do the local backup approach, you will need to run the script manually once a month or set up a cron job to run the script (assuming you want monthly backups.)**

## Running the backup in Docker Compose (Recommended)

The Docker Compose approach is recommended because it is more robust and less error-prone. This is currently run on the LMU OSC server as a service, but you can also run it on your local machine. A cron job within the container triggers the backup script once a month.

### How It Works

When the Docker container starts, the entrypoint executes the following steps:

1. **Environment Setup**: `printenv > /etc/environment` - Writes all environment variables (including `GITHUB_PAT` and `TZ`) to `/etc/environment` so they're available to the cron daemon
2. **Start Cron Service**: `cron` - Starts the cron scheduler daemon inside the container
3. **Tail Logs**: `tail -f /var/log/cron.log` - Keeps the container running and displays cron log output in real-time

The cron jobs are scheduled to run automatically on the **first day of each month at 00:00 UTC** (or your specified timezone):
- `Rscript /archiving_code/backup_all_repos.R` - Archives all repositories and their metadata
- `Rscript /archiving_code/remove_old_backups.R` - Cleans up backups older than 12 months

This setup ensures backups happen consistently without requiring manual intervention.

### Prerequisites

* On MacOS
  1. Install docker with Homebrew: `brew install --cask docker`. The `--cask` flag will also install the Docker Desktop app, needed in the next step.
  2. Start the Docker Desktop app and follow the installation steps (when it asks you to sign in or to create an account: You can skip that.) It is necessary to start the Docker Desktop app on Mac as that starts the Docker daemon.
* On Linux
  1. Follow the instructions on the [Docker website](https://docs.docker.com/engine/install/) specific to your system.
  2. Let the Docker daemon run in the background: `sudo systemctl start docker`

### Setting Up Environment Variables

The backup script requires your GitHub PAT and optionally a timezone setting. These are passed to the container via environment variables:

#### Create a `.env` File (Persistent)

For a more permanent setup, create a `.env` file in the same directory as `docker-compose.yml`:

```sh
# .env file
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxx
TZ=America/Los_Angeles
```

Docker Compose will automatically load these variables when you run `docker compose up`. **Important**: Add `.env` to your `.gitignore` to avoid committing your PAT to version control.


### Start the service

This repository includes [docker-compose.yml](docker-compose.yml), which builds and starts the backup service. The downloaded archive is stored in the container folder `/archive` and on the host at `/srv/backups/github`.

Before starting, set your PAT in the environment (see "Setting Up Environment Variables" above):

```sh
export GITHUB_PAT=<YOUR_TOKEN>
```

Then build and run with Compose:

```sh
docker compose up -d --build
```

### Viewing Logs

There are several ways to check the backup progress and diagnose issues:

#### Live Logs (Following Output)

To see logs in real-time as the service runs:

```sh
# View live logs from docker-compose
docker compose logs -f
```

#### Historical Logs

To view logs without following:

```sh
# View all logs
docker compose logs

# View logs from the last 10 minutes
docker compose logs --since 10m

# View last 100 lines
docker compose logs --tail 100
```

#### Container Logs (Alternative Method)

You can also check logs directly using the container name:

```sh
# Live logs
docker logs -f github-archiver

# View logs with timestamps
docker logs --timestamps github-archiver

# View logs from the last hour
docker logs --since 1h github-archiver
```

#### Inside the Container

To check logs directly inside the container and monitor cron execution:

```sh
# Enter the container shell
docker compose exec github-archiver bash

# View the cron log file
tail -f /var/log/cron.log

# Or view the last 50 lines
tail -50 /var/log/cron.log

# Exit the container
exit
```

### Troubleshooting Log Output

If you see logs but no backup activity:
- Check that `GITHUB_PAT` is set and valid
- Look for cron error messages like "CRON ERROR" or "Rscript: command not found"
- Verify the scheduled time by checking if any jobs have started yet (cron jobs run monthly on the 1st at 00:00)

**Important Notes:**

* The service is named `github-archiver`.
* The host folder `/srv/backups/github` is mounted to `/archive` in the container.
* If needed, edit [docker-compose.yml](docker-compose.yml) to change the volume mapping.
* The cron logs are stored at `/var/log/cron.log` inside the container.
* Backup archives are stored in `/archive/YYYY-MM` format.

If `/srv/backups/github` does not exist yet, create it first:

```sh
sudo mkdir -p /srv/backups/github
```

#### Manually Triggering a Backup

If you need to manually trigger a backup (not recommended, but sometimes necessary), you can enter the container and run the backup script:

```sh
# Enter the container shell
docker compose exec github-archiver bash

# Run the backup script manually
Rscript /archiving_code/backup_all_repos.R

# Exit the container
exit
```

### Stopping and Removing the Container

In case you have to stop/delete a running container, use: 

```
# stop and remove container (keeps archive files on host)
docker compose down
```


# Questions

## What do I do if the GITHUB_PAT has expired?

If your GitHub Personal Access Token has expired, you will need to generate a new one and update the environment variable in your shell (or `.env` file), then recreate the service.

```sh
export GITHUB_PAT=<NEW_TOKEN>
docker compose up -d --force-recreate
```

Alternatively, you can enter the container and set the new environment variable temporarily with the following command:

```sh
docker compose exec github-archiver bash
export GITHUB_PAT=<NEW_TOKEN>
```

## What happens if I modify/delete the files at `/srv/backups/github` on my system or at `/archive` in the container?

You should think of these locations as the same folder. If you delete files in one location, they will be deleted in the other location. If you modify files in one location, they will be modified in the other location. This is because the folder is mounted from your local system to the container.

However, stopping the container and then removing it will not delete the files on your local system. The files will still be there, and you can start a new container with the same volume mount to access the files again. **You must first stop the container and then remove it to keep the files on your local system.**

```sh
docker compose down
```



