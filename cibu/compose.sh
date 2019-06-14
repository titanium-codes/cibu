main(){
    check
    if [[ "$(type -t "$2")" = function ]]; then
        $2 $@
    else
        show_help
    fi
}

check(){
    if [[ -z "$TARGET_HOST" ]]; then
        echo "\$TARGET_HOST environment variable not set"
        show_help
        exit 1
    fi

    if [[ -z "$TARGET_PATH" ]]; then
        echo "\$TARGET_PATH environment variable not set"
        show_help
        exit 1
    fi
}

login(){
    if [[ -z "$3" ]] || [[ -z "$4" ]] || [[ -z $5 ]]; then
        echo "Invalid number of arguments passed!"
        show_help
        exit 1
    fi
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "docker login -u $3 -p $4 $5"
}

upload(){
    SUFFIX=""
    if [[ -n "$3" ]]; then
        SUFFIX="-$3"
    fi
    scp -P ${TARGET_PORT:-22} "docker-compose$SUFFIX.yml" $TARGET_HOST:$TARGET_PATH/docker-compose.yml
}

deploy(){
    if [[ -z "$3" ]] || [[ -z "$4" ]]; then
        echo "Invalid number of arguments passed!"
        show_help
        exit 1
    fi
    sed -i "s/RELEASE_PLACEHOLDER/${RELEASE}/g" $3
    CONTENT=$(cat $3)
    RELEASE=$4
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "
    mkdir -p $TARGET_PATH;
    cd $TARGET_PATH;
    printf \"$CONTENT\" > docker-compose-$RELEASE.yml;
    ln -sf docker-compose-$RELEASE.yml docker-compose.yml;
    docker-compose pull"
}

pull(){
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "cd $TARGET_PATH; docker-compose pull ${@:3}"
}

up(){
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "cd $TARGET_PATH; docker-compose up ${@:3}"
}

update(){
    remove $@
    up dummy dummy -d --force-recreate --remove-orphans --no-deps ${@:3}
}

remove(){
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "cd $TARGET_PATH; docker-compose stop ${@:3}; docker-compose rm -f ${@:3}"
}

cleanup(){
    ssh $TARGET_HOST -p ${TARGET_PORT:-22} "docker system prune -a -f --volumes; rm -rf /var/lib/docker/aufs/diff/*-removing"
}

show_help(){
    echo -e "
    cibu compose <SUBCOMMAND> [args...]

    docker-compose related commands

    SUBCOMMANDS:
    login <login> <password> <registry>
    Run docker login on remote server
    Example cibu compose login user password registry.gitlab.com
    Will run ssh \$TARGET_HOST:\${TARGET_PORT:-22} docker login -u user -p password registry.gitlab.com

    upload [suffix]
    Upload docker-compose file with target suffix (if provided) to remote server.
    Example: cibu compose upload qa
    Will run scp -P 22 docker-compose-qa.yml \$TARGET_HOST:\$TARGET_PATH/docker-compose.yml

    deploy <docker-compose.yml file> <release>
    Complex command:
    1. Replaces RELEASE_PLACEHOLDER in passed docker-compose file with 'release' argument.
    2. Creates \$TARGET_PATH on \$TARGET_HOST if it not exists
    3. Uploads modified docker-compose.yml file to \$TARGET_PATH/docker-compose-\$RELEASE.yml
    4. Creates (force) symlink from docker-compose-\$RELEASE.yml to docker-compose.yml
    5. Performs docker-compose pull
    Example: cibu compose deploy env/dev.yml 0.2.144

    pull [docker-compose pull argumets]
    Perform a 'docker-compose pull' with arguments (if provided) on remote server in selected dir
    Example: cibu compose pull --parallel
    Will run ssh \$TARGET_HOST -p 22 'cd \$TARGET_PATH; docker-compose pull --parallel'

    remove <service>
    Stop and remove selected service
    Example: cibu compose remove redis
    Will run ssh \$TARGET_HOST -p 22 'cd \$TARGET_PATH; docker-compose stop redis; docker-compose rm -f redis'

    up [docker-compose up args...]
    Run docker-compose up command on target server
    Example: cibu compose up --force-recreate
    Will run ssh \$TARGET_HOST -p 22 'cd \$TARGET_PATH; docker-compose up --force-recreate'

    update <service>
    Stop, remove and recreate selected service
    Example: cibu compose update redis
    Will run ssh \$TARGET_HOST -p 22 'cd \$TARGET_PATH; docker-compose stop redis; docker-compose rm -f redis; docker-compose up -d --force-recreate --remove-orphans --no-deps redis'

    cleanup
    Run docker system prune and clean volumes marked to remove
    Example: cibu compose cleanup
    Will run ssh \$TARGET_HOST -p 22 'docker system prune -a -f; rm -rf /var/lib/docker/aufs/diff/*-removing'
    "
}
