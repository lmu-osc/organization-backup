
# LMU OSC Organization Backup

The code in this repo is intended to hit the GitHub API for all of our organization repos so that we can create backups of all of the code, pull requests, issues, and related metadata for all of our repos. This is mostly a worst-case, disaster back-up in case someone were to e.g. get access to our organization and delete all of the content online. Then, we would have local back-ups of our content also available.

## Getting a Github Personal Access Token (PAT)

Both for the local run of the script `backup_all_repos.R` and the Docker approach, you need a Personal Access Token (PAT).
The PAT needs to be a *classic token* and should have the following permissions: `admin:org`, `gist`, `repo`, `user`, `workflow`.

## Run the backup script locally

If you run the script `backup_all_repos.R`, you need to put your PAT into the `~/.Renviron` file (restart R to take the changes into effect), or set it temporarily via `Sys.setenv(GITHUB_PAT = "ghp_...")`. The downloaded archive will be stored in the subfolder `./archive`.

## Running the backup in a Docker container

The idea is that the Docker container always runs in the background (on a server, but could also be on your local machine).
A cron job within the container triggers the backup script once a month.

Prerequisites on MacOS:

1. Install docker with Homebrew: `brew install --cask docker` (it must be the `--cask` version)
2. Launch the Docker Desktop app and follow the installation steps (when it asks you to sign in or to create an account: You can skip that.)

How to create the image and run it:

3. Start the Docker Desktop app (on MacOS, there is no docker daemon - for all following steps, the Docker Desktop app must be running!)

Execute in the terminal:

```sh
# run once: Build the new docker container:
sudo docker build -t lmu-osc-github-archiver .

# Start the container
sudo docker run --name github-archiver -d -v ./lmu_osc_github_archive:/archive -e GITHUB_PAT=<YOUR_TOKEN> lmu-osc-github-archiver
```

If you want to manually trigger a backup (and not wait for the cron job to start it each month):

```
# enter the container (when it has been started):
sudo docker exec -it github-archiver bash

Rscript /archiving_code/backup_all_repos.R
```

The downloaded archive will be stored in the container in the folder `/archive` *and* on your local drive (i.e. on the host system) at the subfolder `./lmu_osc_github_archive`.

In case you have to stop/delete a running container, use: 
```
# check container status
docker ps -a

# stop and remove the container
docker stop github-archiver
docker rm -f github-archiver
```
