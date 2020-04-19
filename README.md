# Install
```sh
mkdir /root/builds
wget https://raw.githubusercontent.com/ShaneMcC/thirdparty-docker-builder/master/run.sh -O /root/builds/run.sh
chmod a+x /root/builds/run.sh
```
Then add a cron entry for /root/builds/run.sh

# Usage
Repos to build are added by creating a directory within `/root/builds` with a
file named `CONFIG`

This file should define `URL` variable and a push target:
```sh
URL="https://git.example.com/someone/something"
TARGETS_REPO=(registry.example.com/someone/something)
```

And optionally a `DOCKERFILE` and `BUILDPATH`:
```sh
DOCKERFILE_REPO=Dockerfile
BUILDPATH_REPO='.'
```

(`DOCKERFILE` and `BUILDPATH` can be omitted if they are 'Dockerfile' and '.')

You can build multiple Dockerfiles if needed by using the `BUILDS` var and then
using separate named vars for each build:

```sh
URL="https://git.example.com/someone/something"
BUILDS=(FIRST SECOND)

DOCKERFILE_FIRST="Dockerfile.first"
TARGETS_FIRST=(registry.example.com/someone/something-first)

DOCKERFILE_SECOND="Dockerfile.first"
TARGETS_SECOND=(registry.example.com/someone/something-second)
```

(Technically, `BUILDS` has a default value of `BUILDS=(REPO)`)
