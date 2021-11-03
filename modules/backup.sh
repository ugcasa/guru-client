#!/bin/bash
# guru-client backup system casa@ujo.guru 2021

source $GURU_BIN/common.sh

backup.help () {
    # general help

    gmsg -v1 -c white "guru-client backup help "
    gmsg -v2
    gmsg -v0 "usage:    $GURU_CALL backup status|list|poll|install|remove  "
    gmsg -v0 "          $GURU_CALL backup <category> now|at <YYYYMMDD> <HH:MM> "
    gmsg -v2
    gmsg -v1 -c white "commands: "
    #gmsg -v1 " now                      make backup now "
    gmsg -v1 " at <YYMMDD> <H:M>        make backup at date"
    gmsg -v1 " ls                       list of backups "
    gmsg -v1 " restore                  not clear hot to be done  "
    gmsg -v1 " install                  install client requirements "
    gmsg -v1 " remove                   remove installed requirements "
    gmsg -v2 " help                     printout this help "
    gmsg -v3 " poll start|end           start or end module status polling "
    gmsg -v2
    gmsg -v1 -c white "example: "
    gmsg -v1 " $GURU_CALL backup status           # printout current backup status"
    gmsg -v1 " $GURU_CALL backup work now         # backup category 'work'"
    gmsg -v1 " $GURU_CALL backup family at 21:00  # backup family stuff at evening "
    gmsg -v1 " $GURU_CALL backup photos at Monday # backup family stuff next Monday"
    gmsg -v2
}


backup.main () {
    # command parser

    local command="$1" ; shift
    case "$command" in

                ls|restore|status|help|install|poll|all|at)
                    gmsg -v3 -c beep_pink "backup.$command $@"
                    backup.$command "$@"
                    return $? ;;

                daily|weekly|monthly)
                    gmsg -v3 -c beep_pink "backup.all $command"
                    backup.all $command
                    return $? ;;
                "")
                    gmsg -v3 -c beep_pink "backup.all daily"
                    backup.all daily
                    return $? ;;
                *)
                    local mount_lists=(${GURU_BACKUP_DAILY[@]} ${GURU_BACKUP_WEEKLY[@]} ${GURU_BACKUP_MONTHLY[@]})
                    local given_items=("$command" "$@")

                    # handle lists given by user
                    for list_item in ${given_items[@]} ; do
                        # check is command on some of schedule lists
                        if grep -w "$list_item" <<<${mount_lists[@]} >/dev/null; then
                                gmsg -v2 -c dark_golden_rod "backing up $list_item.. "
                                backup.now $list_item
                            else
                                gmsg "pls input daily, weekly, mounthly or all"
                                return 0
                            fi
                        done
                    return $? ;;
        esac
    gmsg -c reset "unknown list/schedule '$command'"
    backup.status
    return $?
}


backup.config () {
    # get tunnel configuration an populate common variables

    declare -ga backup_name=($1)
    declare -la header=(store method from ignore)
    declare -ga active_list=(${GURU_BACKUP_DAILY[@]} ${GURU_BACKUP_WEEKLY[@]} ${GURU_BACKUP_MONTHLY[@]})
    declare -g backup_indicator_key="f$(daemon.poll_order backup)"

    # check is enabled
    if ! [[ $GURU_BACKUP_ENABLED ]] ; then
            gmsg -c dark_grey "backup module disabled"
            return 1
        fi

    # exit if not in list
    if ! echo "${active_list[@]}" | grep "$backup_name" >/dev/null ; then
        gmsg -c yellow "no configuration for backup $backup_name"
        return 2
        fi

    gmsg -v3 -c white "active_list: ${active_list[@]}"

    for bu_name in ${active_list[@]} ; do
            if [[ "$bu_name" == "$backup_name" ]] ; then
                local data="GURU_BACKUP_${bu_name^^}[@]" ; data=(${!data})
                gmsg -v3 -c pink "${data[@]}"
                declare -l store_device=${data[0]}
                declare -l method=${data[1]}
                declare -l from=${data[2]}
                declare -l ignore="${data[3]//:/" "}"
                local store="GURU_BACKUP_${store_device^^}[@]" ; store=(${!store})
                break
            fi
        done

        # fill parameters if from seems to be a remote location
        if echo $from | grep ":" >/dev/null ; then
            declare -g from_user=$(echo $from | cut -d ":" -f1)
            declare -g from_domain=$(echo $from | cut -d ":" -f2)
            declare -g from_port=$(echo $from | cut -d ":" -f3)
            declare -g from_location=$(echo $from | cut -d ":" -f4)
        else
            # fill only one parameter if from is local drive
            declare -g from_location=$from
        fi
        # if store is remote drive
        if echo ${store[@]} | grep ":" >/dev/null ; then
            declare -g store_user=$(echo ${store[1]} | cut -d ":" -f1)
            declare -g store_domain=$(echo ${store[1]} | cut -d ":" -f2)
            declare -g store_port=$(echo ${store[1]} | cut -d ":" -f3)
            declare -g store_location=$(echo ${store[1]} | cut -d ":" -f4)
        else
            # fill parameters if store is local drive
            declare -g store_device_file=${store[0]}
            declare -g store_file_system=${store[1]}
            declare -g store_mount_point=${store[2]}
            declare -g store_folder=${store[3]}
            declare -g store_location="$store_mount_point/$store_folder"
        fi

        declare -ga backup_ignore=($ignore)
        declare -g backup_method=$method
        declare -g honeypot_file="$from_location/honeypot.txt"
        return 1
    return 0
}



backup.status () {
    # check latest backup is reachable and returnable.

    local backup_indicator_key="f$(daemon.poll_order backup)"
    local backup_data_folder=$GURU_SYSTEM_MOUNT/backup

    gmsg -n -v1 -t "${FUNCNAME[0]}: "

    if [[ $GURU_BACKUP_ENABLED ]] ; then
            gmsg -n -v1 -c green -k $backup_indicator_key \
                "enabled, "
        else
            gmsg -v1 -c reset -k $backup_indicator_key \
                "disabled"
            return 1
        fi

    if ! [[ -f $backup_data_folder/next ]] ; then
            gmsg -v1 -c green -k $backup_indicator_key \
                "no scheduled backups"
            return 0
        fi

    local epic_backup=$(cat $backup_data_folder/next)
    local diff=$(( $epic_backup - $(date '+%s') ))

    # indicate backup time
    if [[ $diff -lt 3600 ]] ; then
        # indicate that backup will be done within a hour
        gmsg -n -v1 -c aqua_marine -k $backup_indicator_key \
            "scheduled backup at $(date -d @$epic_backup '+%d.%m.%Y %H:%M')"
        # indicate that that backup is very soon, ~minutes
        [[ $diff -lt $GURU_DAEMON_INTERVAL ]] && gmsg -n -v1 -c deep_pink -k $backup_indicator_key \ "($diff seconds)"
        echo
    else
        # all fine, no backup soon
        gmsg -n -v1 -c green -k $backup_indicator_key "on service "
        gmsg -v1 -c reset "next backup $(date -d @$epic_backup '+%d.%m.%Y %H:%M')"
    fi
    return 0
}


backup.ls () {
    # list available backups and its status

    gmsg -c white "daily:"
    for source in ${GURU_BACKUP_DAILY[@]} ; do
            gmsg -n -c light_blue "$source"
        done

    gmsg -c white "weekly:"
    for source in ${GURU_BACKUP_DAILY[@]} ; do
            gmsg -n -c light_blue "$source"
        done

    gmsg -c white "mounthly:"
    for source in ${GURU_BACKUP_DAILY[@]} ; do
            gmsg -n -c light_blue "$source"
        done

    return 0
}


backup.at () {
    # set date and time for next backup

    [[ $1 ]] && local backup_date=$1 || read -p "backup date (YYMMDD): " backup_date
    shift
    [[ $1 ]] && local backup_time=$1 || read -p "backup time (H:M): " backup_time
    shift

    local backup_data_folder=$GURU_SYSTEM_MOUNT/backup

    [[ -d $backup_data_folder ]] || mkdir -p $backup_data_folder

    # TBD all kind of checks for user input

    local epic_now=$(date '+%s')
    local epic_backup=$(date -d "$backup_date $backup_time" '+%s')

    if [[ $epic_now -ge $epic_backup ]] ; then
        gmsg "that is past, try again"
        return 1
    fi

    echo $epic_backup > "$backup_data_folder/next"

    # if daemon is not running (computer sleeping) backup is not run
    # overdue backups shall be run at next start
    return 0
}


backup.restore_wekan () {
    # TBD

    gmsg -c light_blue "docker stop wekan"
    gmsg -c light_blue "docker exec wekan-db rm -rf /data/dump"
    gmsg -c light_blue "docker cp dump wekan-db:/data/"
    gmsg -c light_blue "docker exec wekan-db mongorestore --drop --dir=/data/dump"
    gmsg -c light_blue "docker start wekan"
    return 127
}


backup.restore () {
    # TBD

    backup_method=$1

    case $backup_method in

        wekan)  backup.restore_wekan $from_domain $from_port $from_user $from_location || return $?
                ;;
        mediawiki)
                echo "TBD mediawiki backup restore"
                ;;
        git|gitea)
                echo "TBD git server backup restore"
                ;;
        *)      gmsg -c yellow "unknown method '$backup_method'"
    esac

    return 127
}


backup.wekan () {
    # take a database dump and copy it to location set in user.cfg where normal process can copy it to local

    local _domain=$1
    local _port=$2
    local _user=$3
    local _location=$4

    # stop container
    gmsg -n "stopping docker container.. "
    if ssh ${_user}@${_domain} -p ${_port} -- docker stop wekan >/dev/null ; then
            gmsg -c green "ok"
        else
            gmsg -c yellow "error $?"
            return 128
        fi

    # delete current dump
    gmsg -n "delete last dump.. "
    if ssh ${_user}@${_domain} -p ${_port} -- docker exec wekan-db rm -rf /data/dump >/dev/null ; then
            gmsg -c green "ok"
        else
            gmsg -c yellow "error $?"
            return 129
        fi

    # take a dump
    gmsg -n "take a dump /data/dump.. "
    if ssh ${_user}@${_domain} -p ${_port} -- docker exec wekan-db mongodump -o /data/dump 2>/dev/null ; then
            gmsg -c green "ok"
        else
            gmsg -c yellow "error $?"
            return 130
        fi

    # copy to where to rsyck it to final location
    gmsg -n "copy to ${_location}.. "
    ssh ${_user}@${_domain} -p ${_port} -- "[[ -d ${_location} ]] || mkdir -p ${_location}>/dev/null "

    if ssh ${_user}@${_domain} -p ${_port} -- docker cp wekan-db:/data/dump ${_location} >/dev/null ; then
            gmsg -c green "ok"
        else
            gmsg -c yellow "error $?"
            return 131
        fi

    # start container
    gmsg -n "starting docker container.. "
    if ssh ${_user}@${_domain} -p ${_port} -- docker start wekan >/dev/null ; then
            gmsg -c green "ok"
        else
            gmsg -c yellow "error $?"
            return 132
        fi

    return 0
}


backup.now () {
    # check things and if pass then make backup
    # 1) get config for backup name
    # 2) check and place variables for rsynck
    # 3) check backup method get files out of service containers
    # 4) file checks to avoid broken/infected copy over good files
    # 5) perform copy

### 1) get config for backup name

    backup.config $1

    local from_param="$from_location"
    local store_param="$store_location"
    local command_param="-a --progress --update"

    gmsg -v3 "backup active" -c aqua_marine -k $backup_indicator_key
    #local command_param="-avh '-e ssh -p $from_port' --progress --update"

### 2) check and plase variables for rsynck based on user.cfg

    # if server to server copy..
    if [[ $from_domain ]] && [[ $store_domain ]] ; then
            # build server to server copy command variables
            gask "NEVER TESTED!! continue? " || return 1
            from_param="$from_user@$from_domain 'rsync -ave ssh $from_location $store_user@$store_domain:$from_port:$store_location'"
            store_param=

        # .. or if server to local copy..
        elif [[ $from_domain ]] ; then
            # build remote to local command variables
            command_param="-a -e 'ssh -p $from_port' --progress --update"

            # check is target location mounted and try to mount if not
            if ! mount | grep $store_mount_point >/dev/null ; then

                if [[ $DISPLAY ]] ; then
                        gmsg -n "mounting store media $store_device_file.. "
                        gio mount -d $store_device_file \
                            && gmsg -v1 -c green "ok" \
                            || gmsg -v1 -c yellow "error: $?" -k $backup_indicator_key

                    else
                        gmsg -c white "to mount -t $store_file_system $store_device_file $store_mount_point sudo needed"

                        [[ -d $store_mount_point ]] || sudo mkdir -p $store_mount_point

                        # if [[ $store_file_system == "luks" ]] ; then
                        #         sudo mount -t $store_file_system "/dev/mapper/dev/luks_$store_device_file" $store_mount_point
                        #     else

                        #     fi

                        if sudo mount -t $store_file_system $store_device_file $store_mount_point ; then
                                gmsg -v1 -c green "ok"
                            else
                                gmsg -v1 -c yellow "error: $?" -k $backup_indicator_key
                                return 32
                            fi

                    fi
                    # no rush, my friend
                    sleep 3
                fi

            # if ignores set add arguments
            if [[ $backup_ignore ]] ; then
                for _ignore in  ${backup_ignore[@]} ; do
                    command_param="$command_param --exclude '*$_ignore'"
                done
            fi
            store_param="$store_mount_point/$store_folder"
            from_param="$from_user@$from_domain:$from_location"

        # .. or if local to server copy..
        elif [[ $store_domain ]] ; then
            # build local to remote command variables
            gask "NEVER TESTED!! continue? " || return 1
            command_param="-a -e 'ssh -p $store_port'"
            store_param="$store_user@$store_domain:$store_location"
        # # ..else local to local
        # else
        #     command_param="-a --progress --update"
        #     store_param="$store_location"
        #     from_param="$from_location"
        fi

    # make dir if not exist (like when year changes)
    if ! [[ $store_domain ]] && [[ $store_location ]] ; then
            gmsg -v3 -c deep_pink "mkdir -p $store_location"
            [[ -d $store_location ]] || mkdir -p $store_location
        fi

### 3) check backup method get files out of service containers based settings in user.cfg

    case $backup_method in

            wekan)
                    backup.wekan $from_domain $from_port $from_user $from_location || return $?
                    ;;
            mediawiki)
                    echo "TBD mediawiki backup"
                    ;;
            git|gitea)
                    echo "TBD git server backup"
                    ;;
        esac

### 4) file checks to avoid broken/infected copy over good files

    # crypto virus checks only if from location is remote and store location is local
    if [[ $from_domain ]] && ! [[ $store_domain ]] ; then

        # wannacry test
        local list_of_files=($(ssh $from_user@$from_domain "find $from_location -type f -name '*' "))

        for file in ${list_of_files[@]} ; do

            case $file in

                *.WNCRY*)
                        gmsg -c red -k $backup_indicator_key \
                            "POTENTIAL VIRUS: wannacry tracks detected!"
                        gmsg -c light_blue "$file"
                        gmsg -c yellow "backup of $from_location canceled"
                        return 101
                        ;;

                 *WORM*)
                        echo "TBD other virus track marks here"
                        return 102
                        ;;
                esac
        done

        # check if honeypot file exists
        if ssh $from_user@$from_domain "test -e $honeypot_file" ; then
            [[ -f /tmp/honeypot.txt ]] && rm -f /tmp/honeypot.txt
            gmsg -n "getting honeypot file.. "
            # get honeypot file

            if eval rsync "$command_param" $from_user@$from_domain:$honeypot_file /tmp >/dev/null ; then
                gmsg -c green "ok"
            else
                gmsg -c yellow "cannot get honeypot file"
            fi
        fi
    fi

    # check is text in honeypot.txt file changed
    if [[ -f /tmp/honeypot.txt ]] ; then
            gmsg -n "checking honeypot file.. "
            local contain=($(cat /tmp/honeypot.txt))
            rm -f /tmp/honeypot.txt
            if ! [[ ${contain[3]} == "honeypot" ]] ; then
                gmsg -c yellow \
                     "honeypot file changed! got '${contain[3]}' when 'honeypot' expected."
                gmsg -c light_blue "${contain[@]}"
                gmsg -c red -k $backup_indicator_key \
                     "backup canceled cause of potential crypto virus action detected!"
                #export GURU_BACKUP_ENABLED=false
                return 102
            fi
        gmsg -c green "ok"
    fi

### 5) perform copy
    gmsg -v3 -c deep_pink "eval rsync $command_param $from_param $store_param/$backup_name"
    eval rsync $command_param $from_param $store_param/$backup_name

    local _error=$?
    if [[ $_error -gt 0 ]] ; then
            gmsg -v1 "$from_location error: $backup_method $_error" \
                 -c red -k $backup_indicator_key
            return 12
        else
            gmsg -v3 "$from_location ok" \
                 -c green -k $backup_indicator_key
            return 0
        fi
}


backup.all () {
    # backup all in active list

    local _lists_name=$1
    local item=1;
    local _error=
    local _active_list=()

    case $_lists_name in
        daily)      _active_list=(${GURU_BACKUP_DAILY[@]}) ;;
        weekly)     _active_list=(${GURU_BACKUP_WEEKLY[@]}) ;;
        monthly)    _active_list=(${GURU_BACKUP_MONTHLY[@]}) ;;
        all)        _active_list=(${GURU_BACKUP_DAILY[@]} ${GURU_BACKUP_WEEKLY[@]} ${GURU_BACKUP_MONTHLY[@]}) ;;
            *)      gmsg -c yellow "unknown schedule '$_lists_name', try daily, weekly, monthly or all"
                    read -p "run daily? " answer
                    if [[ ${answer^^} == 'Y' ]] ; then
                            _active_list=(${GURU_BACKUP_DAILY[@]})
                        else
                            return 0
                        fi
        esac

    for source in ${_active_list[@]} ; do
            gmsg -n -c dark_golden_rod "backing up $source $item/${#_active_list[@]}.. "
            #if ! [[ $GURU_BACKUP_ENABLED ]] ; then gmsg -c yellow "canceled" ; break ; fi
            backup.now $source || (( _error++ ))
            (( item++ ))
        done

    if [[ $_error -gt 0 ]] ; then
            gmsg -v1 "$_error warnings, check log above" -c yellow -k $backup_indicator_key
            return 12
        else
            gmsg -v3 "backup done" -c reset -k $backup_indicator_key
            return 0
        fi
}


backup.scheduled () {
        # run an set scheduled backup

        local schedule=$1
        local backup_data_folder=$GURU_SYSTEM_MOUNT/backup
        local epic_backup=$(cat $backup_data_folder/next)

        # if not shedule file, return
        if ! [[ -f $backup_data_folder/next ]] ; then
            return 0
        fi

        # if not shedule file, return
        if [[ $(date '+%s') -lt $epic_backup ]] ; then
            return 0
        fi

        # run given schedule list
        backup.all $schedule
        local _error=$?

        # chedule next backup
        if [[ $_error -lt 100 ]] ; then
            epic_backup=$(( $epic_backup + 86400))
            echo $epic_backup > $backup_data_folder/next
            gmsg -c white \
                "next backup scheduled to $(date -d @$epic_backup '+%d.%m.%Y %H:%M')"
            return $_error
        fi
}


backup.poll () {
    # poll functions

    local backup_indicator_key="f$(daemon.poll_order backup)"
    local _cmd="$1" ; shift

    case $_cmd in
        start )
            gmsg -v1 -t -c black "${FUNCNAME[0]}: backup status polling started" -k $backup_indicator_key
            ;;
        end )
            gmsg -v1 -t -c reset "${FUNCNAME[0]}: backup status polling ended" -k $backup_indicator_key
            ;;
        status )
            backup.status
            backup.scheduled all
            ;;
        *)  gmsg -c dark_grey "function not written"
            return 0
        esac
}


backup.install () {
    # install needed tools

    sudo apt update && \
    sudo apt install ssh scp rsync sshfs pv
    return $?
}


backup.remove () {
    # remove stuff

    gmsg "no point ro remove so basic tools.."
    return 0
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$GURU_RC"
    backup.main "$@"
    exit "$?"
fi

