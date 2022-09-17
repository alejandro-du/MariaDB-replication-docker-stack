source default.env
source custom.env

echo Deleting containers and volumes...

if [[ $SWARM_MODE -gt 0 ]]
then
	docker stack rm mariadb
else
	docker compose down --volumes
fi
