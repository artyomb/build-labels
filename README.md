# build-labels

This gem allows ...  

```
build-labels simple-compose.yml | docker-compose build -f -

$ build-labels
Version: 0.0.53
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
        --cache-from CACHE FROM
                                     type=[local,registry] ... 
        --cache-to CACHE TO
                                     type=[local,registry] ...
    -h, --help

```

https://rdoc.info/gems/build-labels
https://rubydoc.info/gems/build-labels
https://gemdocs.org/gems/build-labels

## Installation
To install the gem

    $ gem install build-labels

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
