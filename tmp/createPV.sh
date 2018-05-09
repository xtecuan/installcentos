#!/bin/bash

for i in `seq 1 10`;
do
	DIRNAME="vol$i"
	mkdir -p /mnt/data/$DIRNAME
        chcon -Rt svirt_sandbox_file_t /mnt/data/$DIRNAME
	chmod 777 /mnt/data/$DIRNAME
	sleep 5
	sed -i "s/name: vol/name: vol$i/g" vol.yaml
	sed -i "s/path: \/mnt\/data\/vol/path: \/mnt\/data\/vol$i/g" vol.yaml
	oc create -f vol.yaml
	echo "created volume $i"
done
