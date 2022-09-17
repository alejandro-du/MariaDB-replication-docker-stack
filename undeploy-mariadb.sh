source default.env
source custom.env

echo Deleting containers and volumes...
docker compose down
docker volume prune -f