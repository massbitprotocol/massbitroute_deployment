_get_running_tag ()
{
	docker ps | grep massbit | cut -d "/" -f 2 | cut -d " " -f 1
}

_cleanup ()
{
	docker rm  $(docker ps | grep _10 | cut -d " " -f 1) -f
	rm -rf /massbit/test_runtime/10 
}
$@
