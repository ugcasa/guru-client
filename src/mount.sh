#!/bin/bash
# mount tools for guru tool-kit
# casa@ujo.guru 2020

source "$GURU_BIN/functions.sh"
source "$GURU_BIN/counter.sh"
source "$GURU_BIN/lib/deco.sh"

mount.main() {
    # mount tool command parser
    argument="$1"; shift
    case "$argument" in
        check-system)       mount.check_system ; return $? ;;
        check)              mount.check "$@"; return $? ;;
        ls|list)            grep "sshfs" < /etc/mtab ;;
        mount)              mount.remote "$1" "$2" ; return $? ;;
        unmount)            mount.unmount "$1" ; return $? ;;
        test)               mount.test "$@" ;;
        help )              mount.help "$@" ;;
        install)            mount.needed install ;;
        unistall|remove)    mount.needed remove ;;
        all|defaults|def)
            case "$GURU_CMD" in
                mount)      mount.defaults_raw ; return $? ;;
                unmount)    unmount.defaults_raw ; return $? ;;
                *)          help
            esac ;;
        *)
            case "$GURU_CMD" in
                mount)      mount.remote "$argument" "$1" ; return $?  ;;
                unmount)    mount.unmount "$argument" ; return $?
                            [ "$1" == "force" ] && sudo fusermount -u "$argument" ;;
                *)          mount.help
            esac
    esac
}


mount.test () {
    mount.online || mount.remote "$GURU_CLOUD_TRACK" "$GURU_TRACK"
    VERBOSE=true
    case "$1" in
        1)
            #mount.check_track || return 1
            #mount.online
            #mount.test_mount
            ;;
        2)
            mount.test_default_mount
            ;;
        all)
            #mount.check_track
            mount.online
            mount.test_mount
            mount.test_default_mount
            ;;
        *)
            echo "no test case for $1"
    esac
}


mount.help() {
    echo "-- guru tool-kit mount help -----------------------------------------------"
    printf "Usage:\t $0 [command] [arguments] \n\t $0 mount [source] [target] \n"
    printf "Commands:\n"
    printf " ls                       list of mounted folders \n"
    printf " check [target]           check that mount point is mounted \n"
    printf " check-system             check that guru system folders are mounted \n"
    printf " mount [source] [target]  mount folder in file server to local folder \n"
    printf " mount all                mount primary file server default folders \n"
    printf "                          Warning! Mount point may be generic location\n"
    printf " unmount [mount_point]    unmount [mount_point] \n"
    printf " unmount [all]            unmount all default folders \n"
    printf " test <case_nr>|all       run given test case \n"
    printf "\nExample:"
    printf "\t %s mount /home/%s/share /home/%s/test-mount/\n" "$GURU_CALL" "$GURU_REMOTE_FILE_SERVER_USER" "$USER"
    return 0
}


mount.check_track() {
    grep "sshfs" < /etc/mtab | grep "$GURU_TRACK" >/dev/null && status="mounted" || status="offline"
    ls -1qA "$GURU_TRACK" | grep -q . >/dev/null 2>&1 && contans_stuff="yes" || contans_stuff=""

    if [ "$status" == "mounted" ] && [ "$contans_stuff" ] && [ -f "$GURU_TRACK/.online" ]; then
        GURU_SYSTEM_STATUS="ready"
        GURU_FILESERVER_STATUS="online"
        return 0

    elif [ "$status" == "mounted" ] && [ "$contans_stuff" ]; then
        GURU_SYSTEM_STATUS="validating system mount.. "
        GURU_FILESERVER_STATUS=".online file not found"
        return 23

    elif [ "$status" == "mounted" ]; then
        GURU_SYSTEM_STATUS="validating system mount.."
        GURU_FILESERVER_STATUS="empty system mount point"
        return 24

    elif [ "$status" == "offline" ]; then
        GURU_SYSTEM_STATUS="offline"
        GURU_FILESERVER_STATUS="offline"
        return 25

    else
        GURU_SYSTEM_STATUS="error"
        GURU_FILESERVER_STATUS="unknown"
        return 255
    fi
}


mount.check_system() {
    msg "checking system mountpoint.. "
    mount.check_track

    result=$?
    if ((result<1)); then
            PASSED
        else
            FAILED
            echo "system status: $GURU_SYSTEM_STATUS"
            echo "fileserver status: $GURU_FILESERVER_STATUS"
            echo "system mount $GURU_FILESERVER_STATUS" >$GURU_ERROR_MSG
        fi
    return $result
}

mount.online() {
    # input: mount point folder.
    # returns: 0 if on line 1 of off line + log and nice colorful output for terminal
    # usage: mount.online mount_point && echo "mounted" || echo "not mounted"
    #        mount.online && OK || ERROR
    local target_folder=$1; shift
    local contans_stuff=""

    if ! [ -d "$target_folder" ]; then
        printf "folder '$target_folder' does not exist" >$GURU_ERROR_MSG
        return 123
    fi

    mount.check_track
    echo "$GURU_FILESERVER_STATUS"
    if ! [ "$GURU_FILESERVER_STATUS"=="online" ]; then
        printf "$ERROR:\nFile server mount unstable \n"         # do not to like write logs if unmounted
        printf "Mount $target_folder status $UNKNOWN \n"
        return 0
    fi

    printf "checking $target_folder status.. "
    grep "sshfs" < /etc/mtab | grep "$target_folder" >/dev/null && local status="mounted" || local status="offline"
    ls -1qA "$target_folder" | grep -q . >/dev/null 2>&1 && contans_stuff="yes" || contans_stuff=""

    if [ status=="mounted" ] && [ "$contans_stuff" ]; then
        printf "$ONLINE"
        return 0
    else
        printf "$OFFLINE"                                                 # if here, Track is online feel free to log
        return 1
    fi
}

mount.check() {
    mount.online "$@"
    return $?
}


mount.unmount () {
    local target_folder="$1"
    # if ! [ -d "$target_folder" ]; then
    #     msg "folder not exist $IGNORED"
    #     return 132
    # fi
    msg "un-mounting $target_folder.. "
    grep "$target_folder" < /etc/mtab >/dev/null || msg "not mounted: "

    if [ $FORCE ]; then
        sudo fusermount -u "$target_folder" >/dev/null && PASSED || FAILED
    else
        mount.online "$target_folder" >/dev/null && fusermount -u "$target_folder" && PASSED || IGNORED    # unmount target if mounted
    fi
}


mount.remote() {
    # input remote_foder and mount_point. servers are already known
    # returns error code of sshfs mount, 0 is success.
    local source_folder="$1"
    local target_folder="$2"

    [ -d "$target_folder" ] ||mkdir -p "$target_folder"                                 # be sure that mount point exist
    mount.online "$target_folder" #>/dev/null && return 0 #mount.unmount "$target_folder"
    [ "$source_folder" == "unmount" ] && return 0                                       # if first argument is "unmount" all done for now, exit
    [ "$(ls $target_folder)" ] && return 23                                             # Check that directory is empty

    local server="$GURU_LOCAL_FILE_SERVER"                                              # assume that server is in local network
    local server_port="$GURU_LOCAL_FILE_SERVER_PORT"
    local user="$GURU_LOCAL_FILE_SERVER_USER"

    if ! ssh -q -p "$server_port" "$user@$server" exit; then                            # check local server connection
        server="$GURU_REMOTE_FILE_SERVER"                                               # if no connection try remote server connection
        server_port="$GURU_REMOTE_FILE_SERVER_PORT"
        user="$GURU_REMOTE_FILE_SERVER_USER"
    fi
    msg "mounting $server $source_folder to $target_folder.. "

    sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 -p "$server_port" "$user@$server:$source_folder" "$target_folder"

    error=$?;
    echo "mounte remote: $error"

    if [ "$error" -lt "1" ]; then
        export GURU_FILESERVER_STATUS="online"
        msg "$READY"
    else
        export GURU_FILESERVER_STATUS="offline"
        export GURU_SYSTEM_STATUS="offline"
        msg "$ERROR mounting failed. sshfs returned code $error\n"
    fi
    return $error                                                                           #&& echo "mounted $server:$source_folder to $target_folder" || error="$
}


mount.defaults_raw() {
    # mount guru tool-kit defaults + backup method if sailing. TODO do better: list of key:variable pairs while/for loop
    if ! mount.online "$GURU_COMPANY"    && [ "$GURU_CLOUD_COMPANY" ];   then mount.remote "$GURU_CLOUD_COMPANY"   "$GURU_COMPANY"; fi
    if ! mount.online "$GURU_FAMILY"     && [ "$GURU_CLOUD_FAMILY" ];    then mount.remote "$GURU_CLOUD_FAMILY"    "$GURU_FAMILY"; fi
    if ! mount.online "$GURU_NOTES"      && [ "$GURU_CLOUD_NOTES" ];     then mount.remote "$GURU_CLOUD_NOTES"     "$GURU_NOTES"; fi
    if ! mount.online "$GURU_TEMPLATES"  && [ "$GURU_CLOUD_TEMPLATES" ]; then mount.remote "$GURU_CLOUD_TEMPLATES" "$GURU_TEMPLATES"; fi
    if ! mount.online "$GURU_PICTURES"   && [ "$GURU_CLOUD_PICTURES" ];  then mount.remote "$GURU_CLOUD_PICTURES"  "$GURU_PICTURES"; fi
    if ! mount.online "$GURU_PHOTOS"     && [ "$GURU_CLOUD_PHOTOS" ];    then mount.remote "$GURU_CLOUD_PHOTOS"    "$GURU_PHOTOS"; fi
    if ! mount.online "$GURU_AUDIO"      && [ "$GURU_CLOUD_AUDIO" ];     then mount.remote "$GURU_CLOUD_AUDIO"     "$GURU_AUDIO"; fi
    if ! mount.online "$GURU_VIDEO"      && [ "$GURU_CLOUD_VIDEO" ];     then mount.remote "$GURU_CLOUD_VIDEO"     "$GURU_VIDEO"; fi
    if ! mount.online "$GURU_MUSIC"      && [ "$GURU_CLOUD_MUSIC" ];     then mount.remote "$GURU_CLOUD_MUSIC"     "$GURU_MUSIC"; fi
    return 0
}


unmount.defaults_raw() {
    # unmount all TODO do better
    unset error
    [ "$GURU_CLOUD_VIDEO" ]       && mount.unmount "$GURU_VIDEO" ; error=$((error+$?))
    [ "$GURU_CLOUD_AUDIO" ]       && mount.unmount "$GURU_AUDIO" ; error=$((error+$?))
    [ "$GURU_CLOUD_MUSIC" ]       && mount.unmount "$GURU_MUSIC" ; error=$((error+$?))
    [ "$GURU_CLOUD_PICTURES" ]    && mount.unmount "$GURU_PICTURES";  error=$((error+$?))
    [ "$GURU_CLOUD_PHOTOS" ]      && mount.unmount "$GURU_PHOTOS" ; error=$((error+$?))
    [ "$GURU_CLOUD_TEMPLATES" ]   && mount.unmount "$GURU_TEMPLATES" ; error=$((error+$?))
    [ "$GURU_CLOUD_NOTES" ]       && mount.unmount "$GURU_NOTES" ; error=$((error+$?))
    [ "$GURU_CLOUD_FAMILY" ]      && mount.unmount "$GURU_FAMILY" ; error=$((error+$?))
    [ "$GURU_CLOUD_COMPANY" ]     && mount.unmount "$GURU_COMPANY" ; error=$((error+$?))

    if [ "$error" -gt "0" ]; then
        msg "Warning: $error of mounts were already unmounted\n" #>"$GURU_ERROR_MSG"
        return 0
    fi

    return 0
}


mount.needed() {
    #install and remove needed applications. input "install" or "remove"
    local action=$1
    [ "$action" ] || read -r -p "install or remove? " action
    local require="ssh rsync"
    printf "Need to install $require, ctrl+c? or input local "
    sudo apt update && eval sudo apt "$action" "$require" && printf "\n guru is now ready to mount\n\n"
}


mount.test_mount() {
    mount.remote "/home/$GURU_USER/usr/test" "$HOME/tmp/test_mount"
    sleep 1
    mount.unmount "$HOME/tmp/test_mount"
    sleep 1
    rm -rf "$HOME/tmp/test_mount" || ERROR
    return 0
}


mount.test_default_mount(){
    msg  "testing sshfs file server default folder mount.. "
    mount.defaults_raw && PASSED || FAILED
    sleep 1
    msg "un-mount defaults.. "
    unmount.defaults_raw && PASSED || FAILED
    return 0
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then        # if sourced only import functions
    source "$HOME/.gururc"
    source "$GURU_BIN/lib/deco.sh"
    source "$GURU_BIN/functions.sh"
    source "$GURU_BIN/counter.sh"
    mount.main "$@"
    exit "$?"
fi

