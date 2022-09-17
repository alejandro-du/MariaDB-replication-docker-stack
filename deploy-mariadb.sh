#!/bin/bash
# Written by Hosein Yousefi <yousefi.hosein.o@gmail.com>
# GitHub: https://github.com/hosein-yousefii/MariaDB-replication-docker-stack
# Modified by Alejandro Duarte <alejandro.duarte@mariadb.com>
# GitHub: https://github.com/alejandro-du/MariaDB-replication-docker-stack

# Automated script to replicate 2 instances of MariaDB.
# The default topology is primary-replica. You can change
# the topology by overriding the TOPOLOGY variable in a
# custom.env file.
# For example:
# TOPOLOGY=multi-primary

primary-replica() {

	echo Creating replication user...
	docker exec $NODE01_CONTAINER_NAME \
		mariadb -u $NODE01_USER --password=$NODE01_PASSWORD \
		--execute="create user '$REPLICATION_USER'@'%' identified by '$REPLICATION_PASSWORD';\
			grant replication replica on *.* to '$REPLICATION_USER'@'%';\
			flush privileges;"

	echo Getting the binary log name and position...
	result=$(docker exec $NODE01_CONTAINER_NAME mariadb -u $NODE01_USER --password=$NODE01_PASSWORD --execute="SHOW MASTER STATUS;")
	log=$(echo $result | awk '{print $5}')
	position=$(echo $result | awk '{print $6}')
	echo using log file: $log
	echo using log position: $position

	echo Connecting replica to primary...
	docker exec $NODE02_CONTAINER_NAME \
		mariadb -u $NODE02_USER --password=$NODE02_PASSWORD \
		--execute="STOP REPLICA;\
			RESET REPLICA;\
			CHANGE MASTER TO MASTER_HOST='$NODE_01_IP', MASTER_USER='$REPLICATION_USER', \
			MASTER_PASSWORD='$REPLICATION_PASSWORD', MASTER_LOG_FILE='$log', MASTER_LOG_POS=$position;\
			START REPLICA;\
			SHOW REPLICA STATUS\G;"

	echo
	echo In case of any errors, check if your containers up and running, then re-run this script.
	echo
	echo Primary node running at $NODE_01_IP:$NODE01_PORT
	echo Replica node running at $NODE_02_IP:$NODE02_PORT
	echo
}

multi-primary() {

	echo Creating replication user on node01...
	docker exec $NODE01_CONTAINER_NAME \
		mariadb -u $NODE01_USER --password=$NODE01_PASSWORD \
		--execute="create user '$REPLICATION_USER'@'%' identified by '$REPLICATION_PASSWORD';\
                        grant replication replica on *.* to '$REPLICATION_USER'@'%';\
                        flush privileges;"

	echo Creating replication user on node02...
	docker exec $NODE02_CONTAINER_NAME \
		mariadb -u $NODE02_USER --password=$NODE02_PASSWORD \
		--execute="create user '$REPLICATION_USER'@'%' identified by '$REPLICATION_PASSWORD';\
                        grant replication replica on *.* to '$REPLICATION_USER'@'%';\
                        flush privileges;"

	echo Getting the binary log name and position on node01...
	node01_result=$(docker exec $NODE01_CONTAINER_NAME mariadb -u $NODE01_USER --password=$NODE01_PASSWORD --execute="SHOW BINLOG STATUS;")
	node01_log=$(echo $node01_result | awk '{print $5}')
	node01_position=$(echo $node01_result | awk '{print $6}')

	echo Getting the binary log name and position on node02...
	node02_result=$(docker exec $NODE02_CONTAINER_NAME mariadb -u $NODE02_USER --password=$NODE02_PASSWORD --execute="SHOW BINLOG STATUS;")
	node02_log=$(echo $node02_result | awk '{print $5}')
	node02_position=$(echo $node02_result | awk '{print $6}')

	echo Connecting node02 to node01...
	docker exec $NODE02_CONTAINER_NAME \
		mariadb -u $NODE02_USER --password=$NODE02_PASSWORD \
		--execute="STOP REPLICA;\
                        RESET REPLICA;\
                        CHANGE MASTER TO MASTER_HOST='$NODE_01_IP', MASTER_USER='$REPLICATION_USER', \
                        MASTER_PASSWORD='$REPLICATION_PASSWORD', MASTER_LOG_FILE='$node01_log', MASTER_LOG_POS=$node01_position;\
                        start replica;\
                        SHOW REPLICA STATUS\G;"

	echo Connecting node01 to node02...
	docker exec $NODE01_CONTAINER_NAME \
		mariadb -u $NODE01_USER --password=$NODE01_PASSWORD \
		--execute="STOP REPLICA;\
                        RESET REPLICA;\
                        CHANGE MASTER TO MASTER_HOST='$NODE_02_IP', MASTER_USER='$REPLICATION_USER', \
                        MASTER_PASSWORD='$REPLICATION_PASSWORD', MASTER_LOG_FILE='$node02_log', MASTER_LOG_POS=$node02_position;\
                        start replica;\
                        SHOW REPLICA STATUS\G;"

	sleep 2
	echo
	echo ###################	node01 status    ###################
	docker exec $NODE01_CONTAINER_NAME \
		mariadb -u $NODE01_USER --password=$NODE01_PASSWORD \
		--execute="SHOW REPLICA STATUS\G;"


	sleep2
	echo
	echo ###################	node02 status    ###################
	docker exec $NODE02_CONTAINER_NAME \
		mariadb -u $NODE02_USER --password=$NODE02_PASSWORD \
		--execute="SHOW REPLICA STATUS\G;"

	sleep 2
	echo
	echo In case of any errors, check if your containers up and running, then re-run this script.
	echo
	echo Primary node 1 running at $NODE_01_IP:$NODE01_PORT
	echo Primary node 2 running at $NODE_02_IP:$NODE02_PORT
	echo

}

source default.env
source custom.env

echo
echo Starting deployment...
echo

if [[ $SWARM_MODE -gt 0 ]]
then
	echo Using Swarm Mode...
	docker stack deploy --compose-file docker-compose.yml mariadb
else
	echo Using Docker Compose...
	docker compose up -d
fi

echo
echo Configuring MariaDB $TOPOLOGY topology...
echo Waiting $WAIT seconds for containers to be up and running...
sleep $WAIT
echo

case ${TOPOLOGY} in

multi-primary)
	multi-primary
	;;

primary-replica)
	primary-replica
	;;

*)
	echo """

# Automated script to replicate 2 instances of MariaDB.
# The default topology is primary-replica. You can change
# the topology by overriding the TOPOLOGY variable in a
# custom.env file.
# For example:
# TOPOLOGY=multi-primary

"""

	;;

esac
