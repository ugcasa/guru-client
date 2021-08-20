#!/bin/bash
# guru shell work time tracker
# casa@ujo.guru 2019-2020
# TODO timer module neewds to be write again.. this is useless, still partly working and in use.
# python might be better than bash for mathematics
source common.sh

timer.main () {
    # main command parser
    command="$1" ; shift
    case "$command" in

        toggle|check|status|start|change|cancel|end|stop|report|log|edit|last|poll)
                timer.$command "$@"
                return $? ;;
        help|*)
                timer.help
                return 0 ;;
    esac
}


timer.help () {
    gmsg -v1 -c white "guru-client timer help "
    gmsg -v2
    gmsg -v0 "usage:    $GURU_CALL timer [start|end|cancel|log|edit|report] <task> <project> <customer> "
    gmsg -v2
    gmsg -v1 " start <task>         start timer for target with last customer and project"
    gmsg -v1 " start at [TIME]      start timer at given time in format HH:MM"
    gmsg -v1 " end|stop             end current task"
    gmsg -v1 " end at [TIME]        end current task at given time in format HH:MM"
    gmsg -v1 " cancel               cancel the current task"
    gmsg -v1 " log                  print out 10 last records"
    gmsg -v1 " edit                 open work time log with $GURU_EDITOR"
    gmsg -v1 " report               create report in .csv format and open it with $GURU_OFFICE_DOC"
    gmsg -v3 " poll start|end       start or end module status polling "
    gmsg -v2
    gmsg -v1 "example:  $GURU_CALL timer start config_stuff projectA customerB "
}


timer.toggle () {
    # key press action
    if timer.status >/dev/null ; then
        timer.end
    else
        timer.start
    fi
    sleep 4
}


timer.check() {
    # check timer state
    timer.status human && return 0 || return 100
    }


timer.status() {
    # output timer status
    timer_indicator_key="f$(daemon.poll_order timer)"
    gmsg -n -t -v1 "${FUNCNAME[0]}: "

    # check is timer set
    if [[ ! -f "$GURU_FILE_TRACKSTATUS" ]] ; then
        gmsg -v1 -c reset "no timer tasks" -k $timer_indicator_key
        return 1
    fi

    # get timer variables
    source "$GURU_FILE_TRACKSTATUS"

    # fill variables
    timer_now=$(date +%s)
    timer_state=$(($timer_now-$timer_start))
    nice_start_date=$(date -d $start_date '+%d.%m.%Y')
    # static for mathematics
    hours=$(($timer_state/3600))
    minutes=$(($timer_state%3600/60))
    seconds=$(($timer_state%60))

    # format output
    [[ $hours > 0 ]] && print_h=$(printf "%0.2f hours " $hours) || print_h=""
    [[ $minutes > 0 ]] && print_m=$(printf "%0.2f minutes " $minutes) || print_m=""
    [[ $hours > 0 ]] && print_s="" || print_s=$(printf "%0.2f seconds" $seconds)

    # select output format
    case "$1" in

        -h|human)
            gmsg "working for $customer from $start_time $nice_start_date, now spend:$print_h$print_m$print_s to $project $task "
            ;;

        -t|table)
            gmsg " Start date      | Start time  | Hours  | Minutes  | Seconds  | Customer  | Project  | Task "
            gmsg " --------------- | ----------- | ------ | -------- | -------- | --------- | -------- | ------------ "
            gmsg " $nice_start_date | $start_time | $hours | $minutes | $seconds | $customer | $project | $task"
            ;;

        -c|csv)
            gmsg "Start date;Start time;Hours;Minutes;Seconds;Sustomer;Project;Task "
            gmsg "$nice_start_date;$start_time;$hours;$minutes;$seconds;$customer;$project;$task"
            ;;

        old)
            gmsg "$nice_start_date $start_time > $hours:$minutes:$seconds c:$customer p:$project t:$task"
            ;;

        simple|*)
            gmsg -v1 -c aqua "$customer $project $task spend: $hours:$minutes" -k $timer_indicator_key
            ;;
    esac

    return 0
}


timer.last() {
    # get last timer state
    if [[ -f $GURU_FILE_TRACKLAST ]] ; then
            gmsg -c light_blue "$(cat $GURU_FILE_TRACKLAST)"
        else
            gmsg -c yellow "no last tasks"
        fi
}


timer.start() {
    # Start timer TBD rewrite this thole module
    timer_indicator_key="f$(daemon.poll_order timer)"
    [[ -d "$GURU_LOCAL_WORKTRACK" ]] || mkdir -p "$GURU_LOCAL_WORKTRACK"

    # check is timer alredy set
    if [[ -f "$GURU_FILE_TRACKSTATUS" ]] ; then
        timer.main end at $(date -d @$(( (($(date +%s)) / 900) * 900)) "+%H:%M")
    fi

    # parse given arguments
    case "$1" in

        at|from)
            shift
            if ! [[ "$1" ]] ; then
                    echo "input start time"
                    return 124
                fi

            if date -d "$1" '+%H:%M' >/dev/null 2>&1; then
                    time=$(date -d "$1" '+%H:%M')
                    shift
                else
                    time=$(date -d @$(( (($(date +%s)) / 900) * 900)) "+%H:%M")
                fi

            if date -d "$1" '+%Y%m%d' >/dev/null 2>&1; then
                    date=$(date -d "$1" '+%Y%m%d')
                    shift
                else
                    date=$(date -d "today" '+%Y%m%d')
                fi
            ;;
        *)
            date=$(date -d "today" '+%Y%m%d')
            time=$(date -d @$(( (($(date +%s)) / 900) * 900)) "+%H:%M")
            ;;
    esac

    # is this really needed? Don't think so
    start_date="$date"
    start_time="$time"
    nice_date=$(date -d $start_date '+%d.%m.%Y')
    timer_start=$(date -d "$start_date $start_time" '+%s')

    gmsg -v1 "starting timer.."
    [[ -f $GURU_FILE_TRACKLAST ]] && source $GURU_FILE_TRACKLAST
    [[ "$1" ]] && task="$1" || task="$last_task"
    [[ "$2" ]] && project="$2" || project="$last_project"
    [[ "$3" ]] && customer="$3" || customer="$last_customer"

    # update work files TODO some other method, soon please
    printf "timer_start=$timer_start\nstart_date=$start_date\nstart_time=$start_time\n" >$GURU_FILE_TRACKSTATUS
    printf "customer=$customer\nproject=$project\ntask=$task\n" >>$GURU_FILE_TRACKSTATUS

    # signal user and others
    gmsg -v1 -c aqua -k $timer_indicator_key "$start_time $customer $project $task"
    gmsg -v4 -m $GURU_USER/message $GURU_TIMER_START_MESSAGE
    gmsg -v4 -m $GURU_USER/status $GURU_TIMER_START_STATUS
    return 0
}


timer.end() {
    # end timer and save to database (file)
    if [ -f $GURU_FILE_TRACKSTATUS ]; then
        source $GURU_FILE_TRACKSTATUS
    else
        gmsg -v1 "timer not started"
        return 13
    fi

    timer_indicator_key="f$(daemon.poll_order timer)"

    case "$1" in
        at|to|till)
            if ! [[ "$2" ]] ; then
                    gmsg "input end time"
                    return 124
                fi

            # Some level of format check
            if date -d "$1" '+%H:%M' >/dev/null 2>&1; then
                    time=$(date -d "$1" '+%H:%M')
                    shift

                else
                    time=$(date -d @$(( (($(date +%s)) / 900) * 900)) "+%H:%M")
                fi

            if date -d "$1" '+%Y%m%d' >/dev/null 2>&1; then
                    date=$(date -d "$1" '+%Y%m%d')
                    shift
                else
                    date=$(date -d "today" '+%Y%m%d')
                fi
            ;;
        *)
            date=$(date -d "today" '+%Y%m%d')
            time=$(date -d @$(( (($(date +%s) + 900) / 900) * 900)) "+%H:%M")
            ;;
    esac

    end_date=$date
    end_time=$time
    timer_end=$(date -d "$end_date $end_time" '+%s')
    dot_start_date=$(date -d $start_date '+%Y.%m.%d')
    dot_end_date=$(date -d $end_date '+%Y.%m.%d')
    nice_start_date=$(date -d $start_date '+%d.%m.%Y')
    nice_end_date=$(date -d $end_date '+%d.%m.%Y')

    (( spend_sec = timer_end - timer_start ))
    (( spend_min = spend_sec / 60 ))
    (( spend_hour = spend_min / 60 ))
    (( spend_min_div = spend_min % 60 ))

    spend_min_dec=$(python -c "print(int(round($spend_min_div * 1.6666, 0)))")
    hours="$spend_hour.$spend_min_dec"

    if [[ "$nice_start_date" == "$nice_end_date" ]]; then
        option_end_date=""
    else
        option_end_date=" ($nice_end_date)"
    fi

    # close track file
    [[ -f $GURU_FILE_TRACKDATA ]] || printf "Start date  ;Start time ;End date ;End time ;Hours ;Customer ;Project ;Task \n" >$GURU_FILE_TRACKDATA
    [[ $hours > 0.11 ]] && printf "$dot_start_date;$start_time;$dot_end_date;$end_time;$hours;$customer;$project;$task\n" >>$GURU_FILE_TRACKDATA
    printf "last_customer=$customer\nlast_project=$project\nlast_task=$task\n" >$GURU_FILE_TRACKLAST
    rm $GURU_FILE_TRACKSTATUS

    # inform
    gmsg -v1 -c reset -k $timer_indicator_key "$start_time - $end_time$option_end_date $customer $project $task spend $hours"
    gmsg -v4 -m $GURU_USER/message $GURU_TIMER_END_MESSAGE
    gmsg -v4 -m $GURU_USER/status $GURU_TIMER_END_STATUS
    return 0
}


timer.stop () {
    # alias stop for end
    timer.end "$@"
    return 0
}


timer.change() {
    # alias change for start
    timer.start "$@"
    gmsg -v1 -c dark_golden_rod "work topic changed"
    return $?
}


timer.cancel() {
    # cancel exits timer
    timer_indicator_key="f$(daemon.poll_order timer)"

    if [ -f $GURU_FILE_TRACKSTATUS ]; then
            rm $GURU_FILE_TRACKSTATUS
            gmsg -v1 -t -c reset -k $timer_indicator_key "work canceled"
            gmsg -v4 -m $GURU_USER/message "glitch in the matrix, something changed"
            gmsg -v4 -m $GURU_USER/status "available"
        else
            gmsg -v1 "not active timer"
        fi
    return 0
}


timer.log () {
    # printout short list of recent records
    printf "last logged records:\n$(tail $GURU_FILE_TRACKDATA | tr ";" "  ")\n"
    return 0
}


timer.edit () {
    # edit data csv file
    $GURU_PREFERRED_EDITOR "$GURU_FILE_TRACKDATA" &
    return 0
}


timer.report() {
    # make a report
    [ "$1" ] && team="$1" || team="$GURU_TEAM"
    report_file="work-track-report-$(date +%Y%m%d)-$team.csv"
    output_folder=$HOME/Documents
    [ "$team" == "all" ] && team=""
    [ -f $GURU_FILE_TRACKDATA ] || return 13

    cat $GURU_FILE_TRACKDATA |grep "$team" |grep -v "invoiced" >"$output_folder/$report_file"
    $GURU_PREFERRED_OFFICE_DOC $output_folder/$report_file &
    timer.end $""
}


timer.poll () {
    # daemon interface
    timer_indicator_key="f$(daemon.poll_order timer)"

    local _cmd="$1" ; shift
    case $_cmd in
        start )
            gmsg -v1 -t -c black "${FUNCNAME[0]}: timer status polling started" -k $timer_indicator_key
            ;;
        end )
            gmsg -v1 -t -c reset "${FUNCNAME[0]}: timer status polling ended" -k $timer_indicator_key
            ;;
        status )
            timer.status $@
            ;;
        *)  timer.help
            ;;
        esac
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$GURU_RC"
    timer.main "$@"
    exit $?
fi

