export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_PROJECT_NAME=mft

export COMPOSE_FILE=./docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mysql/docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./mft/docker-compose.yml
#export COMPOSE_FILE=$COMPOSE_FILE:./dcc/docker-compose.yml