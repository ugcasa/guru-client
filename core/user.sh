#!/bin/bash
# user settings for guru-client
# casa@ujo.guru 2020


# TBD NON FUNCTIONAL: Please review after check there is no usage.
# Do not remove, user.cfg is load cause this exists


user.main () {
    # command parser

    command="$1"; shift

    case "$command" in
        add|rm)
            [ "$1" == "server" ] && ${command}_user_server "$@" || ${command}_user "$@"
            ;;
        info)
            user.info
            ;;
        help)
            echo "usage:    $GURU_CALL user [add|rm|change|help]"
            ;;
        status)
            gr.msg -n -v1 -t "${FUNCNAME[0]}: "
            [[ "$GURU_USER" == "$GURU_USER_NAME" ]] \
                && gr.msg -c green "username OK" \
                || gr.msg -c red "username mismatch! $GURU_USER:$GURU_USER_NAME"
            ;;
        change|*)
            user.change "$@"
            ;;

    esac


}


user.info () {

    gr.msg -h "user information"
    gr.kvp GURU_USER
    gr.kvp GURU_USER_FULL_NAME
    gr.kvp GURU_USER_EMAIL
    gr.kvp GURU_USER_PHONE
    gr.kvp GURU_USER_DOMAIN
    gr.kvp GURU_USER_TEAM

    gr.msg -h "system information"
    gr.kvp GURU_SYSTEM_CALL_NAME
    gr.kvp GURU_SYSTEM_ALIAS
    gr.kvp GURU_SYSTEM_LOCATION
    gr.kvp GURU_SYSTEM_MOUNT

    gr.msg -h "service information"
    gr.kvp GURU_SERVICE_DOMAIN
    gr.kvp GURU_ACCESS_DOMAIN
    gr.kvp GURU_CLOUD_DOMAIN
}


user.set_value () {
    # set value to user (or any) config file

    [ -f "$GURU_SYSTEM_RC" ] && target_rc="$GURU_SYSTEM_RC" || target_rc="$GURU_RC"        #
    #[ $3 ] && target_rc=$3
    sed -i -e "/$1=/s/=.*/=$2 $3 $4/" "$target_rc"

}

user.add () {
    # add user (futile)

    [ "$1" ] && new_user="$1" || read -p "user name to change to : " new_user
    echo "adding $new_user"
    # ask/get user name
    # make config folder
    # copy user config template to user name
    # add user add request to server
    # add keys to server
    # user.change
    return 0
}
user.add_server () {
    # Run this only at accesspoint server for now

    echo "add user to access point server TBD"
    [ "$1" ] && new_user="$1" || read -p "user name to add : " new_user
    echo sudo adduser "$new_user"
    echo mkdir -p "usr/cfg"
}

user.change () {
    # change user, futile done bu guru config export -u <username>

    [ "$1" ] && new_user="$1" || read -p "user name to change to : " new_user

    new_user_rc=$GURU_CFG/$new_user/userrc2

    if [ -d "$new_user_rc" ]; then
        echo "user exist"
        user.set_value GURU_USER "${new_user,,}"             # set user to en
        source "$new_user_rc"                           # get user configuration on use
        pull_config_files                               # get newest configurations from server
    else
        read -p "user do not exist, create it? : " answer
        [ "${answer,,}" == "y" ] && add_user "$new_user" || return 1
    fi

    # pull onfig files (just overwrite)
    # change environment values
    return 0
}

# if not runned from terminal, use as library
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    #source "$GURU_RC"
    user.main "$@"
    return 0
fi


