
# LMU OSC Organization Backup

The code in this repo is intended to hit the GitHub API for all of our organization repos so that we can create backups of all of the code, pull requests, issues, and related metadata for all of our repos. This is mostly a worst-case, disaster back-up in case someone were to e.g. get access to our organization and delete all of the content online. Then, we would have local back-ups of our content also available.

The main script for this is `backup_all_repos.R`. It is intended to be run once a week (Sunday) to keep the back-ups up-to-date. The script will download all of the content of all of the repos in the organization and store them in a folder called `./archive/YYYY-MM`.

## Getting a Github Personal Access Token (PAT)

Both for the local run of the script `backup_all_repos.R` and the Docker approach, you need a Personal Access Token (PAT).

The PAT needs to be a *classic token* and should have the following permissions: 

* `admin:org`
* `gist`
* `repo`
* `user`
* `workflow`

You can create a new token by going to your GitHub account settings, then Developer settings, then Personal access tokens, and then Generate new token.

## Run the backup script locally

If you run the script `backup_all_repos.R`, you need to put your PAT into your system environment. There are two approaches to this:

* Add it to the `~/.Renviron` file (restart R to take the changes into effect)
* Set it via `Sys.setenv(GITHUB_PAT = "ghp_...")`. The downloaded archive will be stored in the subfolder `./archive`.

**Note that if you do the local backup approach, you will need to run the script manually once a week or set up a cron job to run the script (assuming you want weekly backups.)**

## Running the backup in a Docker container (Recommended)

The Docker container approach is recommended because it is more robust and less error-prone. This is currently run on the LMU OSC server as a service that runs once a week, but you can also run it on your local machine. A cron job within the container triggers the backup script once a week.

### Prerequisites

* On MacOS
  1. Install docker with Homebrew: `brew install --cask docker`. The `--cask` flag will also install the Docker Desktop app, needed in the next step.
  2. Start the Docker Desktop app and follow the installation steps (when it asks you to sign in or to create an account: You can skip that.) It is necessary to start the Docker Desktop app on Mac as that starts the Docker daemon.
* On Linux
  1. Follow the instructions on the [Docker website](https://docs.docker.com/engine/install/) specific to your system.
  2. Let the Docker daemon run in the background: `sudo systemctl start docker`

### Build the Image

The Dockerfile in this repository contains the instructions to build the Docker image. The image is based on the `rocker/r-ver:4.3.3` image, which is a lightweight R image. The image will be built with the name `lmu-osc-github-archiver`.

Execute the shell code below in the terminal. Note that `sudo` may or may not be needed, depending on the permissions on your system. If you have `sudo` access, you will be accessed for your password when running these commands.

```sh
# run once: Build the new docker container:
sudo docker build -t lmu-osc-github-archiver .
```

### Start the Container

After building an image, you can start a container from that image. The container will run the backup script once a month. The downloaded archive will be stored in the container in the folder `/archive` *and* on your local drive (i.e. on the host system) at the subfolder `./lmu_osc_github_archive`.

Here are some notes about the command below:

* `--name github-archiver` gives the container a name that you can use to refer to it later.
* `-d` runs the container in the background.
* `-v ./lmu_osc_github_archive:/archive` mounts the local folder (i.e. on your computer) `./lmu_osc_github_archive` to the container folder `/archive`. This is where the downloaded archive will be stored. Because the relative path `./lmu_osc_github_archive` is used, make sure you pay attention to where you are in your terminal when executing this by checking with `pwd`.
    * **Note: on the OSC server, we use `/lmu_osc_github_archive` i.e. the absolute root of the server**. This is so that the output is not placed in any particular user's home space.
* `-e GITHUB_PAT=<YOUR_TOKEN>` sets the environment variable `GITHUB_PAT` in the container to your GitHub Personal Access Token. This will then be available to the R script.
* `lmu-osc-github-archiver` is the name of the image that you built in the previous step.

```
# Start the container
sudo docker run --name github-archiver -d -v ./lmu_osc_github_archive:/archive -e GITHUB_PAT=<YOUR_TOKEN> lmu-osc-github-archiver

# For the OSC server only
sudo docker run --name github-archiver -d -v /lmu_osc_github_archive:/archive -e GITHUB_PAT=<YOUR_TOKEN> lmu-osc-github-archiver
```

#### Entering the Container

If you want to enter the container to check the status of the backup or to manually trigger a backup, you can do so with the following commands:

```sh
# enter the container (when it has been started):
sudo docker exec -it github-archiver bash
```


This is not recommended, but if you **need** to manually trigger a backup for some reason, you can then execute the following code *from within the container*:

```sh
Rscript /archiving_code/backup_all_repos.R
```

### Stopping and Removing the Container

In case you have to stop/delete a running container, use: 

```
# check container status
docker ps -a

# stop and remove the container
docker stop github-archiver
docker rm -f github-archiver
```


# Questions

## What do I do if the GITHUB_PAT has expired?

If your GitHub Personal Access Token has expired, you will need to generate a new one and update the environment variable in the container. You can do this by stopping the container, removing it, and then starting a new container with the new token.

Alternatively, you can enter the container and set the new environment variable with the following command:

```sh
docker exec -it github-archiver bash
export GITHUB_PAT=<NEW_TOKEN>
```

## What happens if I modify/delete the files at `./lmu_osc_github_archive` on my system or at `/archive` in the container?

You should think of these locations as the same folder. If you delete files in one location, they will be deleted in the other location. If you modify files in one location, they will be modified in the other location. This is because the folder is mounted from your local system to the container.

However, stopping the container and then removing it will not delete the files on your local system. The files will still be there, and you can start a new container with the same volume mount to access the files again. **You must first stop the container and then remove it to keep the files on your local system.**

```sh
docker stop github-archiver
docker rm -f github-archiver
```



