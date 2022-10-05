docker ps | grep massbit | cut -d "/" -f 2 | cut -d " " -f 1

docker rm  $(docker ps | grep _10 | cut -d " " -f 1) -f
