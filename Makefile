# include some Docker specific make functions
include ../docker-makeinc/docker.mk

# name and version for image and container
SERVICE_NAME = mercurial-server-app
DATA_NAME = mercurial-server-data
VERSION = 1.0.dev
SERVICE_IMAGE = $(SERVICE_NAME):$(VERSION)
DATA_IMAGE = $(DATA_NAME):$(VERSION)

# port numbers and IP addresses
#
# container - ssh port number used by hg in container
HG_SSHPORT_CONTAINER = 8022
# host - ssh port number used by host machine
HG_SSHPORT_HOST = 8022
# address of local host. Don't use 0.0.0.0 or leave blank
# the 127 address limits container access to the local machine only
LOCALHOST = 127.0.0.1

# container names
#
# name of data volume container
DATAVOLUME = $(DATA_NAME)

# environment variables to pass
ENVVARS = -e HG_ROOTUSER_KEYS="$(shell ssh-add -L)"
# links to other containers
LINKS =
# volumes exposed by the data container
VOLUMES = -v /var/lib/mercurial-server/repos
# data container volumes are used by the application container
VOLUMES_FROM = --volumes-from $(DATAVOLUME)
# port assignments
PORTS = -p $(LOCALHOST):$(HG_SSHPORT_HOST):$(HG_SSHPORT_CONTAINER)
# additional options
#
.PHONY: build build_app build_data run run-app create-data start stop rm rmi mv-app mv-data


# build images
#
build: build_data

build_app:
	# force build new application image
	# the old image will lose its tag, but will still be there
	# the application container will not be affected
	docker build -t $(SERVICE_IMAGE) -f Dockerfile-app .

build_data: build_app
	# force build new data image
	# the old image will lose its tag, but will still be there
	# the data container will not be affected
	docker build --build-arg SERVICE_IMAGE=$(SERVICE_IMAGE) -t $(DATA_IMAGE) -f Dockerfile-data .

# create and run containers
#
run: run-app

run-app: create-data mv-app
	# create and run the container
	docker run $(OPTIONS) $(ENVVARS) $(LINKS) $(VOLUMES_FROM) $(PORTS) --name $(SERVICE_NAME) -d $(SERVICE_IMAGE)

create-data: mv-data
	# create the data container
	docker create $(VOLUMES) --name $(DATA_NAME) $(DATA_IMAGE) /bin/true

# starting and stopping application container
#
start:
	docker start $(SERVICE_NAME)

stop:
	# stop container if it is running
	if [ "$(call docker-does-container-run,$(SERVICE_NAME))" != "yes" ] ; \
		then docker stop $(SERVICE_NAME); fi

# remove application container
#
rm: stop
	# remove old container if one exists
	if [ "$(call docker-does-container-exist,$(SERVICE_NAME))" != "yes" ] ; \
		then docker rm $(SERVICE_NAME); fi

# remove application image
#
rmi: rm
	# remove old image if one exists
	if [ "$(call docker-does-image-exist,$(SERVICE_IMAGE))" != "yes" ] ; \
		then docker rmi $(SERVICE_IMAGE); fi

mv-app: stop
	# rename old application container(s)
	if docker inspect $(SERVICE_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter "name=${SERVICE_NAME}*"|sort -r)) \
		echo application containers found $(CONTAINERS) ; \
 		$(foreach C,$(CONTAINERS),$(shell docker container rename $(C) $(C).old)) \
	fi

mv-data: stop
	# rename old data container(s)
	if docker inspect $(DATA_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter "name=${DATA_NAME}*"|sort -r)) \
		echo data containers found $(CONTAINERS) ; \
 		$(foreach C,$(CONTAINERS),$(shell docker container rename $(C) $(C).old)) \
	fi
