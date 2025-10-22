#   Active Transfer deployment using Docker / Podman

NOTE: the provided up.sh and down.sh are configured to use podman, you can change them to use docker.

##  Database initialization

Update the setenv.sh as follows, in order to only start the MySQL container:

```
export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_PROJECT_NAME=mft

export COMPOSE_FILE=./docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mysql/docker-compose.yml
#export COMPOSE_FILE=$COMPOSE_FILE:./mft/docker-compose.yml
#export COMPOSE_FILE=$COMPOSE_FILE:./dcc/docker-compose.yml
```

To start the container:
```
./up.sh
```

Then, once the database container is health, uncomment the dcc line:
```
export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_PROJECT_NAME=mft

export COMPOSE_FILE=./docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mysql/docker-compose.yml
#export COMPOSE_FILE=$COMPOSE_FILE:./mft/docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./dcc/docker-compose.yml
```

To start the container (without touching the MySQL container):
```
./up.sh
```

To follow the execution of the DCC scripts:
```
podman logs -f dcc
```

Once the DCC has successfully done its job, remove the container:
```
podman rm dcc
```

##  Deployment of Active Transfer Server

Update the setenv.sh to remove DCC from the add, and add th MFT container 

```
export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_PROJECT_NAME=mft

export COMPOSE_FILE=./docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mysql/docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mft/docker-compose.yml
#export COMPOSE_FILE=$COMPOSE_FILE:./dcc/docker-compose.yml
```

Then to start it:
```
./up.sh
```

To check the MFT container logs:
```
podman logs -f mft
```

##  Undeployment

Use the shutdown script:
```
./up.sh
```