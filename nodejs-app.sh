#!/bin/bash

arg(){
    name=$1
    value=$2
    msg=$3
    default=$4

    VARIABLES+=("${name}")

    if [[ -z "${value}" ]]
    then
        read -e -p "${msg} : " -i "${default}" value
    fi
    eval ${name}=\"${value}\"
}

process(){
    for name in "${VARIABLES[@]}"; do
        eval value=\$${name}
        TEMPLATE=`sed "s|__${name}__|${value}|g" <<< "${TEMPLATE}"`
    done

    read -e -p "Is above correct? (Y/n): " -i "y" confirm

    if [[ "${confirm}" != "y" ]]
    then
        exit 0
    fi

    echo "${TEMPLATE}" > "/etc/init.d/${NAME}"
    cat "/etc/init.d/${NAME}"
}

arg NAME "${1}" "Script name in /etc/init.d" "node-app"
arg USER "${2}" "User" "root"
arg NODE_ENV "${3}" "Node environment" "production"
arg PORT "${4}" "Port" "3000"
arg APP_DIR "${5}" "App dir" "/var/www/example.com"
arg NODE_APP "${6}" "Node app" "app.js"
arg KWARGS "${7}" "Args" ""
arg CONFIG_DIR "${8}" "Config dir" '$APP_DIR'
arg PID_DIR "${9}" "PID dir" '$APP_DIR/pid'
arg PID_FILE "${10}" "PID dir" '$PID_DIR/app.pid'
arg LOG_DIR "${11}" "Log dir" '$APP_DIR/log'
arg LOG_FILE "${12}" "Log file" '$LOG_DIR/app.log'
arg NODE_EXEC "${13}" "Node" $(which node)
arg APP_NAME "${14}" "App name" "Node app"

TEMPLATE=$(cat <<'END_HEREDOC'
#!/bin/sh

USER="__USER__"
NODE_ENV="__NODE_ENV__"
PORT="__PORT__"
APP_DIR="__APP_DIR__"
NODE_APP="__NODE_APP__"
KWARGS="__KWARGS__"
CONFIG_DIR="__CONFIG_DIR__"
PID_DIR="__PID_DIR__"
PID_FILE="__PID_FILE__"
LOG_DIR="__LOG_DIR__"
LOG_FILE="__LOG_FILE__"
NODE_EXEC="__NODE_EXEC__"
APP_NAME="__APP_NAME__"

###############

# REDHAT chkconfig header

# chkconfig: - 58 74
# description: node-app is the script for starting a node app on boot.
### BEGIN INIT INFO
# Provides: node
# Required-Start:    $network $remote_fs $local_fs
# Required-Stop:     $network $remote_fs $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: start and stop node
# Description: Node process for app
### END INIT INFO

###############

USAGE="Usage: $0 {start|stop|restart|status} [--force]"
FORCE_OP=false

pid_file_exists() {
    [ -f "$PID_FILE" ]
}

get_pid() {
    echo "$(cat "$PID_FILE")"
}

is_running() {
    PID=$(get_pid)
    ! [ -z "$(ps aux | awk '{print $2}' | grep "^$PID$")" ]
}

start_it() {
    mkdir -p "$PID_DIR"
    chown $USER:$USER "$PID_DIR"
    mkdir -p "$LOG_DIR"
    chown $USER:$USER "$LOG_DIR"

    echo "Starting $APP_NAME ..."
    echo "cd $APP_DIR && PORT=$PORT NODE_ENV=$NODE_ENV NODE_CONFIG_DIR=$CONFIG_DIR $NODE_EXEC $APP_DIR/$NODE_APP $KWARGS 1>$LOG_FILE 2>&1 & echo \$! > $PID_FILE" | sudo -i -u $USER
    echo "$APP_NAME started with pid $(get_pid)"
}

stop_process() {
    PID=$(get_pid)
    echo "Killing process $PID"
    pkill -P $PID
}

remove_pid_file() {
    echo "Removing pid file"
    rm -f "$PID_FILE"
}

start_app() {
    if pid_file_exists
    then
        if is_running
        then
            PID=$(get_pid)
            echo "$APP_NAME already running with pid $PID"
            exit 1
        else
            echo "$APP_NAME stopped, but pid file exists"
            if [ $FORCE_OP = true ]
            then
                echo "Forcing start anyways"
                remove_pid_file
                start_it
            fi
        fi
    else
        start_it
    fi
}

stop_app() {
    if pid_file_exists
    then
        if is_running
        then
            echo "Stopping $APP_NAME ..."
            stop_process
            remove_pid_file
            echo "$APP_NAME stopped"
        else
            echo "$APP_NAME already stopped, but pid file exists"
            if [ $FORCE_OP = true ]
            then
                echo "Forcing stop anyways ..."
                remove_pid_file
                echo "$APP_NAME stopped"
            else
                exit 1
            fi
        fi
    else
        echo "$APP_NAME already stopped, pid file does not exist"
        exit 1
    fi
}

status_app() {
    if pid_file_exists
    then
        if is_running
        then
            PID=$(get_pid)
            echo "$APP_NAME running with pid $PID"
        else
            echo "$APP_NAME stopped, but pid file exists"
        fi
    else
        echo "$APP_NAME stopped"
    fi
}

case "$2" in
    --force)
        FORCE_OP=true
    ;;

    "")
    ;;

    *)
        echo $USAGE
        exit 1
    ;;
esac

case "$1" in
    start)
        start_app
    ;;

    stop)
        stop_app
    ;;

    restart)
        stop_app
        start_app
    ;;

    status)
        status_app
    ;;

    *)
        echo $USAGE
        exit 1
    ;;
esac
END_HEREDOC
)

process