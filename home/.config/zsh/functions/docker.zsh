# ~/.config/zsh/functions/docker.zsh

docker_mysql() {
  containers=($(docker ps --format '{{.Names}}'))
  select container in $containers; do
    docker exec -it $container sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
    break
  done
}

docker_bash() {
  containers=($(docker ps --format '{{.Names}}'))
  select container in $containers; do
    docker exec -it $container bash
    break
  done
}
