# build-labels

This gem allows ...  

```
build-labels simple-compose.yml | docker-compose build -f -

$ build-labels
Version: 0.0.21
Usage:
	build-labels -c docker-compose.yml gitlab
	cat docker-compose.yml | build-labels gitlab
	build-labels gitlab < docker-compose.yml

Commands:
     to_compose -  Add labels to all build sections of docker-compose file
     to_dockerfiles -  Add ENVs to Dockerfiles from docker-compose file
     gitlab -  Use GitLab CI variables
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
      labels: []
  service-b:
    image: service-a
    build:
      context: "."
      labels: []

```
