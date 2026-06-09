# ============================================================================ #
#                                   VARIABLES                                  #
# ============================================================================ #

NAME          = inception
COMPOSE_FILE  = srcs/docker-compose.yml

# Physical paths on the host system where data will persist
# These must match the values defined inside your srcs/.env file
WP_DATA_PATH  = /home/claudio/data/wordpress
DB_DATA_PATH  = /home/claudio/data/mariadb

# ============================================================================ #
#                                 RULES & TARGETS                              #
# ============================================================================ #

.PHONY: all up down start stop build clean fclean re

all: up

up:
	@echo "Creating persistent volume storage directories on host..."
	@sudo mkdir -p $(WP_DATA_PATH) $(DB_DATA_PATH)
	@sudo chmod 777 $(WP_DATA_PATH) $(DB_DATA_PATH)
	@echo "Building and launching multi-container infrastructure in background..."
	@docker compose -f $(COMPOSE_FILE) up --build -d

down:
	@echo "Stopping and tearing down active infrastructure containers..."
	@docker compose -f $(COMPOSE_FILE) down

start:
	@docker compose -f $(COMPOSE_FILE) start

stop:
	@docker compose -f $(COMPOSE_FILE) stop

build:
	@docker compose -f $(COMPOSE_FILE) build

clean: down
	@echo "Cleaning up dangling Docker objects..."
	@docker system prune -a -f

fclean: clean
	@echo "CRITICAL: Removing all persistent database and website records from host..."
	@sudo rm -rf $(WP_DATA_PATH) $(DB_DATA_PATH)
	@echo "Removing all local Docker volumes volume blocks..."
	@if [ -n "$$(docker volume ls -q)" ]; then docker volume rm $$(docker volume ls -q); fi

re: fclean all

PHONY: all up down start stop build clean fclean re