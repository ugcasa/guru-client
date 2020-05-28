#!/bin/bash
# mount tools for guru tool-kit
source "$HOME/.gururc"
source $GURU_BIN/lib/common.sh


GURU_MOUNT_DOCUMENTS=("/home/casa/Documents" "/home/casa/Documents")
GURU_MOUNT_TRACK=("/home/casa/Track" "/home/casa/Track")
GURU_MOUNT_NOTES=("/home/casa/Notes" "/home/casa/Notes")
GURU_MOUNT_TEMPLATES=("/home/casa/Templates" "/home/casa/Templates")
GURU_MOUNT_COMPANY=("/home/casa/ujo.guru" "/home/casa/ujo.guru")
GURU_MOUNT_FAMILY=("/home/casa/bubble" "/home/casa/bubble.bay")
GURU_MOUNT_PICTURES=("/home/casa/Pictures" "/home/casa/Pictures")
GURU_MOUNT_PHOTOS=("/home/casa/Photos" "/home/casa/Photos")
GURU_MOUNT_AUDIO=("/home/casa/Videos" "/home/casa/Audio")
GURU_MOUNT_VIDEO=("/home/casa/Audio" "/home/casa/Videos")
GURU_MOUNT_MUSIC=("/home/casa/Music" "/home/casa/Music")



mount.main () {                         # mount command parser

    argument="$1"; shift
    case "$argument" in
                     all)   mount.defaults                                     ; return $? ;;
                      ls)   mount.list                                          ; return $? ;;
                    info)   mount.info | column -t -s $' '                      ; return $? ;;
                  status)   mount.status                                        ; return $? ;;
                   check)   mount.online "$@"                                   ; return $? ;;
            check-system)   mount.check "$GURU_LOCAL_TRACK"                     ; return $? ;;
           mount|unmount)   case "$1" in all) $argument.defaults $@ ; return $? ;;
                                           *) $argument.remote $@ ; return $?   ;;
                                esac                                            ; return $? ;;
          install|remove)   mount.install "$argument"                           ; return $? ;;
       help|help-default)   mount.$argument "$1"                                ; return 0  ;;
                       *)   if [ "$1" ] ; then mount.remote "$argument" "$1"    ; return $? ; fi
                            case $GURU_CMD in
                                mount|unmount)
                                    case $argument in
                                    all) $GURU_CMD.defaults                     ; return $? ;;
                                      *) $GURU_CMD.known_remote "$argument"     ; return $? ;;
                                    esac                                                    ;;
                                *) echo "$GURU_CMD: bad input '$argument' "     ; return 1  ;;
                                esac                                                        ;;
                            esac
}

mount.help () {                         # printout help
    echo "-- guru tool-kit mount help -----------------------------------------------"
    printf "usage:\t\t %s mount [source] [target] \n" "$GURU_CALL"
    printf "\t\t %s mount [command] [known_mount_point|arguments] \n" "$GURU_CALL"
    printf "commands:\n"
    printf " check-system             check that guru system folders are mounted \n"
    printf " check [target]           check that mount point is mounted \n"
    printf " mount [source] [target]  mount folder in file server to local folder \n"
    printf " unmount [mount_point]    unmount [mount_point] \n"
    printf " mount all                mount primary file server default folders (*) \n"
    printf " unmount [all]            unmount all default folders \n"
    printf " ls                       list of mounted folders \n"
    printf " more information of adding default mountpoint type '%s mount help-default' \n" "$GURU_CALL"
    printf "\nexample:"
    printf "\t %s mount /home/%s/share /home/%s/test-mount\n" "$GURU_CALL" "$GURU_CLOUD_FAR_USER" "$USER"
  z
}

mount.help-default () {                 # printout instructions to set/use GURU_CLOUD_* definations to userrc
    echo "-- guru tool-kit mount help-default --------------------------------------------"
    printf "\nTo add default mount point type ${WHT}%s config user${NC} or edit user configuration \n" "$GURU_CALL"
    printf "file: ${WHT}%s${NC} \n" "$GURU_USER_RC"

    printf "\n${WHT}Step 1)${NC}\n On configuration dialog find settings named 'GURU_LOCAL_*' \n"
    printf "and add new line: ${WHT}export GURU_LOCAL_<MOUNT_POINT>=${NC} where <MOUNT_POINT> \n"
    peintf "is replaced with single word and up cased. Name will be used as mount point folder name"
    printf "when mounting or un-mounting individual mount point \n"
    printf "After equal sing specify mount point folder between quotation marks. \n"

    printf "\n${WHT}Step 2)${NC}\n Then find on configuration dialog find settings named GURU_CLOUD_* \n"
    printf "and add new line: ${WHT}eexport GURU_REMOTE_<MOUNT_POINT>=${NC} where <MOUNT_POINT> is replaced \n"
    printf "with same word as used in local. Specify mount point folder between quotation marks. \n"
    printf "\nSave and exit. Configuration is applied when next time %s is run. \n" "$GURU_CALL"
    printf "\nPath to success: \n"
    printf " - use single word up case for mount variable name \n"
    printf " - do not use spaces around equal signs \n"
    printf " - use '' quotation if path or filename name contains spaces \n"
    printf " - environmental variables can be used, not then use single quotation \n"
    printf " - use same word for local and cloud variable name \n"
    printf "\nexample:\n GURU_LOCAL_PORN=\"/home/%s/porn\" \n GURU_REMOTE_PORN=\"/server/full/of/bon-jorno\" \n" "$USER"

    return 0
}

mount.status () {                       # check status of GURU_CLOUD_* mountpoints defined in userrc
    local _verbose=$GURU_VERBOSE ; GURU_VERBOSE=true
    local _active_mount_points=$(mount.list)
    local _error=0
    for _mount_point in ${_active_mount_points[@]}; do
        mount.check $_mount_point
        done
    GURU_VERBOSE=$_verbose
    return 0
}

mount.info () {                         # detailed list of mounted mountpoints
    # nice list of information of sshfs mount points
    local _error=0
    [ $TEST ] || msg "${WHT}user@server remote_folder local_mountpoint  uptime pid${NC}\n"                 # header (stdout when -v)
    mount -t fuse.sshfs | grep -oP '^.+?@\S+?:\K.+(?= on /)' |                                          # get the mount data

    while read mount ; do                                                                               # Iterate over them
        mount | grep -w "$mount" |                                                                      # Get the details of this mount
        perl -ne '/.+?@(\S+?):(.+)\s+on\s+(.+)\s+type.*user_id=(\d+)/;print "'$GURU_USER'\@$1 $2 $3"'   # perl magic thanks terdon! https://unix.stackexchange.com/users/22222/terdon
        _error=$?
        local _mount_pid="$(pgrep -f $mount | head -1)"
        _mount_age="$(ps -p $_mount_pid o etime | grep -v ELAPSED | xargs)"
        echo " $_mount_age $_mount_pid"

    done

    ((_error>0)) && msg "perl not installed or internal error, pls try to install perl and try again."
    return $_error
}

mount.list () {                         # simple list of mounted mountpoints
    mount -t fuse.sshfs | grep -oP '^.+?@\S+? on \K.+(?= type)'
    return $?
}

mount.system () {                       # mount system data
    if ! mount.online "$GURU_LOCAL_TRACK"; then
            mount.remote "$GURU_CLOUD_TRACK" "$GURU_LOCAL_TRACK"
        fi
}

mount.online () {                       # check if mountpoint "online", no printout, return code only
    # input: mount point folder.
    # usage: mount.online mount_point && echo "mounted" || echo "not mounted"
    local _target_folder="$1"

    if [[ -f "$_target_folder/.online" ]] ; then
        return 0
    else
        return 1
    fi
}

mount.check () {                        # check mountpoint is mounted, output status
    # check mountpoint status with putput
    local _verbose=$GURU_VERBOSE ; GURU_VERBOSE=true
    local _target_folder="$1"
    local _err=0
    [[ "$_target_folder" ]] || _target_folder="$GURU_LOCAL_TRACK"

    msg "$_target_folder status "
    mount.online "$_target_folder" ; _err=$?

    if [[ $_err -gt 0 ]] ; then
            OFFLINE
            GURU_VERBOSE=$_verbose
            return 1
        fi
    MOUNTED
    GURU_VERBOSE=$_verbose
    return 0
}

mount.remote () {                       # mount remote location
    # input remote_foder and mount_point
    local _source_folder=""
    if [[ "$1" ]] ; then _source_folder="$1"; else read -r -p "input source folder at server: " _source_folder ; fi

    local _target_folder=""
    if [[ "$2" ]] ; then _target_folder="$2"; else read -r -p "input target mount point: " _target_folder ; fi

    if mount.online "$_target_folder"; then
            ONLINE "$_target_folder"                                        # already mounted
            return 0
        fi

    # TODO important: clean-up messy and unclear now, can cause file losses

    if [[ "$(ls -A $_target_folder >/dev/null)" ]] ; then                              # Check that targed directory is empty
            WARNING "$_target_folder is not empty\n"

            if [[ $GURU_FORCE ]] ; then
                    local _reply=""
                    FORCE=                                                  # Too dangerous to continue if set
                    ls "$_target_folder"
                    read -r -p "remove above files and folders?: " _reply
                    if [[ $_reply == "y" ]] ; then

                            if ! [[ -f "$_target_folder/.online" ]] ; then      # to be sure that non of other processes did just now mounted the folder
                                    rm -r "$_target_folder"
                                fi

                        else
                            ERROR "unable to mount $_target_folder, mount point contains files\n"
                            return 25
                        fi
                else
                    printf "try '-f' to force or: %s -f mount %s %s\n" "$GURU_CALL" "$_source_folder" "$_target_folder"
                    return 25
                fi
        fi

    if ! [[ -d "$_target_folder" ]] ; then
        mkdir -p "$_target_folder"                                          # be sure that mount point exist
        fi

    local server="GURU_CLOUD_LAN_IP"                                  # assume that server is in local network
    local server_port="$GURU_CLOUD_PORT"
    local user="$GURU_CLOUD_USERNAME"

    if ! ssh -q -p "$server_port" "$user@$server" exit ; then                # check local server connection
            server="$GURU_CLOUD_DOMAIN"                               # if no connection try remote server connection
            server_port="$GURU_CLOUD_LAN_PORT"
            user="$GURU_CLOUD_USERNAME"
        fi

    msg "mounting $_target_folder "

    sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 -p "$server_port" "$user@$server:$_source_folder" "$_target_folder"
    error=$?

    if ((error>0)) ; then
            WARNING "source folder not found, check $GURU_USER_RC\n"
            [[ -d "$_target_folder" ]] && rmdir "$_target_folder"
            return 25
        else
            MOUNTED
            return 0                                                         # && echo "mounted $server:$_source_folder to $_target_folder" || error="$
        fi
}

unmount.remote () {                     # unmount mountpoint

    local _mountpoint="$1"

    if ! mount.online "$_mountpoint" ; then
            IGNORED "$_mountpoint is not mounted"
            return 0
        fi

    if fusermount -u "$_mountpoint" ; then
            UNMOUNTED "$_mountpoint"
            return 0
        fi

    # once more or if force
    if [ "$GURU_FORCE" ] || mount.online "$_mountpoint" ; then

            printf "force unmount.. "
            if fusermount -u "$_mountpoint" ; then

                    UNMOUNTED "$_mountpoint force"
                    return 0
                else
                    if sudo fusermount -u "$_mountpoint" ; then
                            UNMOUNTED "$_mountpoint SUDO FORCE"
                            return 0
                        else
                            FAILED "$_mountpoint SUDO FORCE unmount"
                            WARNING "seems that some of open program like terminal or editor is blocking unmount, try to close those first\n"
                            return 1
                    fi
            fi
    fi

    return 0
}

mount.defaults () {                     # mount all GURU_CLOUD_* defined in userrc
    # mount all local/cloud pairs defined in userrc

    declare -i _error=0
    [[ -f ~/.gururc2 ]] && source ~/.gururc2 || echo "no file"

    local _default_list=($(cat ~/.gururc2 |grep "export GURU_MOUNT" | sed 's/^.*MOUNT_//' | cut -d "=" -f1))

    msg "default list: ${_default_list[@],,}"

    for _item in "${_default_list[@]}" ; do                       # go trough of found variables
        _source=$(eval echo '${GURU_MOUNT_'"${_item}[0]}")        #
        _target=$(eval echo '${GURU_MOUNT_'"${_item}[1]}")        #
        msg "${_item,,} to "
        mount.remote "$_source" "$_target" || _error=$?
    done

}

unmount.defaults () {                   # unmount all GURU_CLOUD_* defined in userrc
    # unmount all local/cloud pairs defined in userrc
    local _target=""
    local _source=""
    local _error=0
    local _default_list=($(cat "$GURU_USER_RC" |grep "export GURU_LOCAL" | sed 's/^.*LOCAL_//' | cut -d "=" -f1))

    for _default_item in ${_default_list[@]}; do
        _target=$(eval echo '$'"GURU_LOCAL_${_default_item^^}")
        [[ "$_target" ]] || [[ -d "$_target" ]] || continue             # skip if not defined in userrc or mount point does not exist
        unmount.remote "$_target" || _error=$?
    done
    return $_error
}

mount.known_remote () {                 # mount single GURU_CLOUD_* defined in userrc
    local _target=$(eval echo '$'"GURU_LOCAL_${1^^}")
    local _source=$(eval echo '$'"GURU_CLOUD_${1^^}")

    mount.remote "$_source" "$_target"
    return $?
}

unmount.known_remote () {               # unmount single GURU_CLOUD_* defined in userrc
    local _target="$(eval echo '$'"GURU_LOCAL_${1^^}")"
    unmount.remote "$_target"
    return $?
}

mount.install () {                      # install needed software
    #install and remove install applications. input "install" or "remove"
    local action="$1"
    [[ "$action" ]] || read -r -p "install or remove? " action
    local require="ssh rsync"
    printf "Need to install $require, ctrl+c? or input local "
    sudo apt update && eval sudo apt "$action" "$require" && printf "\n guru is now ready to mount\n\n"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] ; then    # if sourced only import functions
        source "$HOME/.gururc"
        mount.main "$@"
        exit "$?"
    fi

# case art {
    # source $GURU_BIN/lib/common.sh
    #                                                      ####
    # mount.main () {                                     ######
    #     # mount tool command parser                       ##
    #                                                     ######
    #     argument="$1"; shift             ##################################
    #                                 ############################################
    #     case "$argument" in       # --------------------------------------------------
    #                     info)   mount.info | column -t -s $' '                    ; return $? ;;  ######
    #             check-system)   mount.check "$GURU_LOCAL_TRACK"                     ; return $? ;; ##  ###
    #          unistall|remove)   mount.install remove                                    ; return $? ;;    ###
    #        help|help-default)   mount.$argument "$@"                                    ; return 0  ;;     ##
    #            mount|unmount)   $argument.remote "$@"                                    ; return $? ;;     ##
    #                  install)   mount.install install                                    ; return $? ;;      ##
    #                   status)   mount.status                                         ; return $? ;;        ##
    #                    check)   mount.online "$@"                             ; return $? ;;             ###
    #                       ls)   mount.list                               ; return $? ;;               ####
    #                         *)   if [ "$1" ] ; then mount.remote "$argument" "$1"    ; return $? ; fi #
    #                             case $GURU_CMD in                            ############
    #                                 mount|unmount)                     #######
    #                                     case $argument in          ###
    #                                     all) $GURU_CMD.defaults      ; return $? ;;
    #                                       *) $GURU_CMD.known_remote "$argument" ; return $? ;;
    #                                     esac                                      ;;
    #                                 *) echo "$GURU_CMD: bad input '$argument' "   ; return 1  ;;
    #                                 esac                                      ;;
    #                          esac  # ------------------------------------------- ########
    # }