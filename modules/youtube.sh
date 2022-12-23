#!/bin/bash
# play and get from youtube casa@ujo.guru 2022

declare -g audio_mpv_socket="/tmp/mpvsocket"
declare -g audio_mpv_options="--input-ipc-server=$audio_mpv_socket"
declare -g audio_now_playing="/tmp/guru-cli_audio.playing"

youtube.help () {

    gr.msg -v1 "guru-cli youtube help " -c white
    gr.msg -v2
    gr.msg -v0  "usage:    $GURU_CALL youtube get|play|audio|install|uninstall|help"
    gr.msg -v2
    gr.msg -v1 "commands: " -c white
    gr.msg -v2
    gr.msg -v1 "  <search string>     search and play "
    gr.msg -v1 "  get|dl <id|url>     download media to media folder "
    gr.msg -v1 "  play <id|url>       play episode from stream"
    gr.msg -v1 "  install             install requirements"
    gr.msg -v1 "  uninstall           remove requirements "
    gr.msg -v1 "  help                this help window"
    gr.msg -v2
    gr.msg -v1 "examples: " -c white
    gr.msg -v2
    gr.msg -v1 "  $GURU_CALL youtube juna kulkee taas"
    gr.msg -v1 "  $GURU_CALL youtube play eF1D-W27Wzg"
    gr.msg -v1 "  $GURU_CALL youtube get https://www.youtube.com/watch?v=eF1D-W27Wzg"
    gr.msg -v2
}


youtube.main () {

    local command=$1
    shift

    case "$command" in

        install|uninstall|upgrade|play)
            youtube.$command $@
            ;;

        get|dl|download)
            for item in "$@"
                do
                   youtube.get_media $item
                done
            ;;

        search)
            youtube.search_n_play $@
            ;;

        audio|song|music)
            youtube.audio $@
            ;;

        play)
            gr.msg -v2 -c white "getting shit from $2"
            echo $2 >$audio_now_playing
            youtube-dl --pipe "$2" 2>/dev/null | mpv -
            rm $audio_now_playing
            ;;

        status) gr.msg -c dark_grey "no status data" ;;

        help)
            youtube.help $@
            ;;
        *)
            youtube.search_n_play $@
            ;;

        esac

    return 0
}


youtube.search_n_play () {
# search input and play it from youtube
    local base_url="https://www.youtube.com"
    export ARGS=$@
    query=`python3 - << EOF
import os
from youtube_search import YoutubeSearch
results = YoutubeSearch(os.environ['ARGS'], max_results=1).to_json()
print(results)
EOF`
    local title=$(echo $query | jq | grep title | cut -d':' -f 2 | xargs | sed 's/,//g')
    local duration=$(echo $query | jq | grep duration | cut -d':' -f 2 | xargs | sed 's/,//g')
    local media_address=$base_url$(echo $query | jq | grep url_suffix | cut -d':' -f 2 | xargs)
    gr.msg -v1 -h "$title ($duration) "
    gr.msg -v2 $media_address
    echo $title >$audio_now_playing
    youtube-dl $media_address -o - 2>/dev/null | mpv $audio_mpv_options - >/dev/null
    rm $audio_now_playing
}


youtube.get_media () {
# get media from tube
    id=$1
    url_base="https://www.youtube.com/watch?v"
    source mount.sh
    mount.main video

    [[ -d $data_location ]] || mkdir -p $GURU_MOUNT_VIDEO

    youtube-dl --version || video.install

    gr.msg -c white "downloading $url_base=$id to $GURU_MOUNT_VIDEO.. "
    youtube-dl --ignore-errors --continue --no-overwrites \
           --output "$GURU_MOUNT_VIDEO/%(title)s.%(ext)s" \
           "$url_base=$id"
}


youtube.audio () {
# get media from tube
    local id=$1
    local url_base="https://www.youtube.com/watch?v"
    source mount.sh
    mount.main audio

    [[ -d $GURU_MOUNT_AUDIO/new ]] || mkdir -p $GURU_MOUNT_AUDIO/new

    youtube-dl --version || video.install

    gr.msg -c white "downloading $url_base=$id to $GURU_MOUNT_AUDIO.. "
    youtube-dl -x --audio-format mp3 --ignore-errors --continue --no-overwrites \
           --output "$GURU_MOUNT_AUDIO/%(title)s.%(ext)s" \
           "$url_base=$id"
}


youtube.play () {
# play input file
    echo "$1" | grep "https://" && base_url="" || base_url="https://www.youtube.com/watch?v"
    gr.msg "getting from url $base_url=$1"
    youtube-dl "$base_url=$1" #2>/dev/null #| mpv -

}


youtube.upgrade() {
# pip3 install --user --upgrade youtube-dl
    gr.msg -c blue "${FUNCNAME[0]}: TBD"
}


youtube.install() {
# install requirements
    sudo apt install detox mpv youtube-dl ffmpeg
    pip3 install --upgrade pip
    pip3 install youtube-search
    jq --version >/dev/null || sudo apt install jq -y
    gr.msg -c green "Successfully installed"
}


youtube.uninstall(){
# remove requirements
    sudo -H pip3 unisntall --user youtube-dl youtube-search
    sudo apt remove youtube-dl -y
    gr.msg -c green "uninstalled"
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$GURU_RC"
    youtube.main "$@"
fi

# some tests
# query=$(python3 - << EOF
# print("$@")
# from youtube_search import YoutubeSearch
# results = YoutubeSearch('$@', max_results=1).to_json()
# print(results)
# EOF
# )

# code=$(cat <<EOF
# print($1)
# from youtube_search import YoutubeSearch
# results = YoutubeSearch('$1', max_results=1).to_json()
# print(results)
# EOF
# )
# query=$(python3 -c "$code")

# printf $@ >/tmp/to.find

# code=$(cat <<EOF
# f = open("/tmp/to.find","r")
# lines = str(f.readlines())

# from youtube_search import YoutubeSearch
# results = YoutubeSearch(lines, max_results=1).to_json()
# print(results)
# EOF
# )

# query=$(python3 -c "$code")


## nice to have functions (from yle.sh)

# youtube.place_media () {
# # NON TESTED: placer copied from yle.sh
#     location="$@"

#     media_file_format="${youtube_media_filename: -5}"
#     media_file_format="${media_file_format#*.}"
#     #media_file_format="${media_file_format^^}"
#     gr.msg -c deep_pink "media_file_format: $media_file_format, youtube_media_filename $youtube_media_filename"

#     if ! [[ -f $youtube_media_filename ]] ; then
#             gr.msg -c yellow "file $youtube_media_filename not found"
#             return 124
#         fi

#     #$GURU_CALL tag "$youtube_media_filename" "youtube $(date +$GURU_FILE_DATE_FORMAT) $youtube_media_title $media_url"

#     source mount.sh
#     case "$media_file_format" in

#         mp3|wav)
#             mount.main audio
#             location="$GURU_MOUNT_AUDIO" ;;


#         mkv|mp4|src|sub|avi)
#             mount.main video
#             location="$GURU_MOUNT_TV" ;;
#         *)
#             mount.main downloads
#             location="$GURU_MOUNT_DOWNLOADS" ;;
#     esac

#     # input overwrites basic shit
#     if [[ "$1" ]] ; then
#             location="$1"
#             shift
#         fi

#     [[ -d $location ]] || mkdir -p $location

#     # moving to default location
#     gr.msg -c white "saving to: $location/$youtube_media_filename"
#     mv -f $youtube_media_filename $location
# }


# youtube.get_subtitles () {

#     [ -d "$youtube_temp" ] && rm -rf "$youtube_temp"
#     mkdir -p "$youtube_temp"
#     cd "$youtube_temp"
#     youtube-dl "$media_url" --subtitlesonly #2>/dev/null
#     #youtube_media_filename=$(detox -v * | grep -v "Scanning")
#     #youtube_media_filename=${youtube_media_filename#*"-> "}
# }


# block_rev () {
#     # trick to reverse array without reversing strings
#     array=($@)

#     f() { array=("${BASH_ARGV[@]}"); }

#     shopt -s extdebug
#     f "${array[@]}"
#     shopt -u extdebug

#     echo "${array[@]}"
# }


# youtube.place () {

#     find_files () {
#         for entry in $@ ; do
#               [[ -f $entry ]] && echo $entry
#             done
#     }

#     split_filename () {
#         local filename=$1
#         local pos=0
#         local episode=
#         local name=

#         sepa='-'

#         for type in ${left[@]} ; do

#             (( pos++ ))

#             case $type in
#                 name)
#                         name="$name$(echo $filename | cut -f $pos -d $sepa) "
#                         ;;
#                 episode)
#                         word="$(echo $filename | cut -f $pos -d $sepa) "

#                         if grep -ve 's0' -ve 'e0' <<<$word ; then
#                             episode="$episode$word"
#                         else
#                             code=$word
#                             break
#                         fi

#                         ;;
#                     esac
#             done

#         pos=0
#         for type in ${right[@]} ; do

#                 (( pos++ ))

#                 case $type in
#                     ending)
#                             sepa='.'
#                             ending="$(echo $filename | cut -f 1 -d $sepa)"
#                             ;;
#                     time)
#                             sepa='t'
#                             time="$(echo $filename | cut -f $pos -d $sepa)"
#                             ;;
#                     day)
#                             day="$(echo $filename | cut -f $pos -d $sepa)"
#                             ;;
#                     month)  month="$(echo $filename | cut -f $pos -d $sepa)"
#                             ;;
#                     year)   year="$(echo $filename | cut -f $pos -d $sepa)"
#                             ;;
#                         esac
#                 done

#         gr.msg "name: $name"
#         gr.msg "episode: $episode"
#         gr.msg "ending: $ending"
#         gr.msg "day: $day"
#         gr.msg "month: $month"
#         gr.msg "time: $time"

#         }

#     files=($(find_files '*mp4 *mkv'))
#     gr.msg -v3 -c light_blue "files: ${files[@]}"

#     sepa='-'
#     left=(name name name name name episode episode episode episode episode episode episode)


#     #right_rev=(ending time day month year code)
#     right=(code year month day time ending)

#     # gr.msg "order: ${left[@]} $(block_rev ${right_rev[@]})"
#     gr.msg "order: ${left[@]} ${right[@]}"

#     for file in ${files[@]} ; do
#         split_filename $file

#         done

# }


# youtube.get_metadata () {
# # CANNOT WORK copy from yle.sh

#     local error=
#     local meta_data="$youtube_temp/meta.json"

#     # make temp if not exist already
#     [[ -d "$youtube_temp" ]] || mkdir -p "$youtube_temp"
#     cd "$youtube_temp"

#     local base_url="https://areena.youtube.fi/"
#     # do not add base url if it already given
#     if echo $1 | grep "http" ; then
#             base_url=
#         fi

#     media_url="$base_url$1"

#     gr.msg -v3 -c deep_pink "media_url: $media_url"

#     # Check if id contain youtube_episodes, then select first one (newest)
#     youtube_episodes=($(youtube-dl --showepisodepage $media_url | grep -v $media_url))
#     # episode_ids=($(youtube-dl $media_url --showmetadata | jq '.[].program_id'))
#     gr.msg -v3 -c light_blue "youtube_episodes: ${youtube_episodes[@]}"

#     # change media address poin to first episode
#     [[ ${youtube_episodes[0]} ]] && media_url=${youtube_episodes[0]}

#     # Get metadata
#     youtube-dl $media_url --showmetadata > $meta_data

#     grep "error" $meta_data && error=$(cat $meta_data | jq '.[].flavors[].error')

#     if [[ $error ]] ; then
#             echo "$error"
#             return 100
#         fi

#     # set variables (like they be local anyway)
#     youtube_media_title="$(cat "$meta_data" | jq '.[].title')"
#     gr.msg -v2 "${youtube_media_title//'"'/""}"

#     youtube_media_address="$media_url "
#     #$(cat "$meta_data" | jq '.[].webpage')
#     #youtube_media_address=${youtube_media_address//'"'/""}
#     youtube_media_filename=$(cat "$meta_data" | jq '.[].filename')
# }

