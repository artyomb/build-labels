# build-labels

This gem allows ...  

```
build-labels simple-compose.yml | docker-compose build -f -

$ build-labels
Version: 0.0.56
Usage:
	build-labels -c docker-compose.yml gitlab
	cat docker-compose.yml | build-labels gitlab
	build-labels gitlab < docker-compose.yml

Commands:
     to_compose -  Add labels to all build sections of docker-compose file
     to_dockerfiles -  Add ENVs to Dockerfiles from docker-compose file
     gitlab -  Use GitLab CI variables
     github -  Use GitHub CI variables
     cache -  Add cache section
     print -  Print labels to stdout
     set_version -  Add version tag from [docker_context]/.version file to image

Options:
    -c, --compose COMPOSE_FILE       Compose file
    -e, --env FILE                   Load .build_info FILE
    -n, --no-env                     Do not process env variables
        --except FILTER
                                     filter services 
        --cache-from CACHE FROM
                                     type=[local,registry] ... 
        --cache-to CACHE TO
                                     type=[local,registry] ...
        --full-version
                                     Push full version tag
    -h, --help

```

https://rdoc.info/gems/build-labels
https://rubydoc.info/gems/build-labels
https://gemdocs.org/gems/build-labels

## Installation
To install the gem

    $ gem install build-labels

## Image vulnerability checks

`trivy-runner` scans locally built images using Docker/Buildx and a Trivy container; no local Trivy installation is needed. It requires the metadata file produced by the build:

```sh
docker buildx bake -f bake.yml --set '*.output=type=docker' --sbom=false --provenance=false --metadata-file /tmp/bake-metadata.json
trivy-runner -f bake.yml --metadata-file /tmp/bake-metadata.json --image-src docker --fail-on HIGH,CRITICAL
```

Run from the same directory and with the same environment as the build. Append Bake target/group names when scanning a subset. The file defaults to `bake.yml`; `--metadata-file` is required. This version supports Docker-local images with one platform per target.

The runner resolves tags with `docker buildx bake --print`, checks every selected tag against its build image ID, and scans each distinct image ID once. It checks the tags again after successful scans. Empty Compose service lists are skipped. Exit status is 0 on success and 1 on an invalid input, image mismatch, vulnerability-policy failure, or tool failure. Trivy's scan output is streamed to the terminal.

`--fail-on` accepts comma-separated `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`, ignoring case; the default is `HIGH,CRITICAL`. Scanning covers vulnerabilities, including unfixed findings under Trivy's default configuration.

Each scan uses `docker run --rm` with `aquasec/trivy:0.74.0`; set `TRIVY_IMAGE` to override the scanner image, including a digest-pinned reference. The container mounts `/var/run/docker.sock` from the Docker daemon host and uses the persistent named volume `trivy-cache` at `TRIVY_CACHE_DIR` (default `/root/.cache/trivy`). This requires the daemon's standard Unix socket; remote/rootless socket layouts are not automatically mapped. Use a trusted scanner image because socket access grants access to the Docker daemon.

Other `TRIVY_*` variables are forwarded to the container. Local configuration/ignore files and other environment variables are not automatically shared; file paths must exist inside the scanner image or its cache volume. An outer build container's cache bind mount is not used by the scanner's named volume.

Building, testing, publishing, and SBOM generation/signing are separate operations. Run this command before publication, and keep local image tags stable through the scan/push interval; the runner does not lock the shared Docker daemon.

## Usage
Create the file `simple-compose.yml` which describes the images to build
```yaml
version: '3.8'

services:
  service-a:
    image: service-a
    build:
      context: .
      dockerfile: ./Dockerfile
    ports:
      - 8080
    environment:
      - hello
  service-b:
    image: service-a
    build: .
  service-c:
    image: service-a


```
Then run in the current directory

    $ build-labels -c simple-compose.yml gitlab

This will ...

```yaml
---
version: '3.8'
services:
  service-a:
    image: service-a
    build:
      context: "."
      dockerfile: "./Dockerfile"
      labels:
      - org.opencontainers.image.vendor=/
      - org.opencontainers.image.authors=/
      - org.opencontainers.image.revision=d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - org.opencontainers.image.ref.name=:master
      - org.opencontainers.image.source=https://gitlab.com//dev1/reports
      - org.opencontainers.image.documentation=https://gitlab.com//dev1/reports
      - org.opencontainers.image.licenses=https://gitlab.com//dev1/reports
      - org.opencontainers.image.url=https://gitlab.com//dev1/reports
      - org.opencontainers.image.title=reports
      - org.opencontainers.image.version=master
      - com.gitlab.ci.user=/
      - com.gitlab.ci.tagorbranch=master
      - com.gitlab.ci.commiturl=https://gitlab.com//dev1/reports/commit/d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - com.gitlab.ci.mrurl=https://gitlab.com//dev1/reports/-/merge_requests/
      - com.gitlab.ci.tag=:d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - com.gitlab.ci.commit_branch=master
      - com.gitlab.ci.commit_short_sha=d17e5c66
      - com.gitlab.ci.commit_timestamp=2022-11-15T17:21:59+03:00
      - com.gitlab.ci.commit_message=update
      - docker.service.name=service-a
      - org.label-schema.url=https://gitlab.com//dev1/reports
      - org.label-schema.vcs-url=https://gitlab.com//dev1/reports
      - org.label-schema.version=master
      - org.label-schema.vcs-ref=d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - org.label-schema.vendor=/
      - org.label-schema.name=reports
      - org.label-schema.usage=https://gitlab.com//dev1/reports
      - org.label-schema.schema-version=1.0
  service-b:
    image: service-a
    build:
      context: "."
      labels:
      - org.opencontainers.image.vendor=/
      - org.opencontainers.image.authors=/
      - org.opencontainers.image.revision=d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - org.opencontainers.image.ref.name=:master
      - org.opencontainers.image.source=https://gitlab.com//dev1/reports
      - org.opencontainers.image.documentation=https://gitlab.com//dev1/reports
      - org.opencontainers.image.licenses=https://gitlab.com//dev1/reports
      - org.opencontainers.image.url=https://gitlab.com//dev1/reports
      - org.opencontainers.image.title=reports
      - org.opencontainers.image.version=master
      - com.gitlab.ci.user=/
      - com.gitlab.ci.tagorbranch=master
      - com.gitlab.ci.commiturl=https://gitlab.com//dev1/reports/commit/d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - com.gitlab.ci.mrurl=https://gitlab.com//dev1/reports/-/merge_requests/
      - com.gitlab.ci.tag=:d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - com.gitlab.ci.commit_branch=master
      - com.gitlab.ci.commit_short_sha=d17e5c66
      - com.gitlab.ci.commit_timestamp=2022-11-15T17:21:59+03:00
      - com.gitlab.ci.commit_message=update
      - docker.service.name=service-b
      - org.label-schema.url=https://gitlab.com//dev1/reports
      - org.label-schema.vcs-url=https://gitlab.com//dev1/reports
      - org.label-schema.version=master
      - org.label-schema.vcs-ref=d17e5c66b8d101f9e54d68e1e8540279bbe25467
      - org.label-schema.vendor=/
      - org.label-schema.name=reports
      - org.label-schema.usage=https://gitlab.com//dev1/reports
      - org.label-schema.schema-version=1.0

```
