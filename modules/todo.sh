# guru-cli project todo collector



# declare -g todo_list="$GURU_PROJECT_FOLDER/todo.list"
# #declare -g todo_pre_list_file="$GURU_PROJECT_FOLDER"

# # [[ -d ${todo_list%/*} ]] || mkdir -p ${todo_list%/*}
# [[ -f $todo_list ]] || touch $todo_list


# todo.see () {

#     source project.sh

#     if ! [[ $GURU_PROJECT_FOLDER ]] ; then
#         gr.msg -c error "not in project"
#         gr.msg -v2 "try '$GURU_CALL project terminal'"
#         return 127
#     fi

#     project.run "$GURU_PREFERRED_EDITOR $todo_list/$PROJECT_NAME"
# }

# todo.see




# todo.add () {
# # add manually to "to do" list

#     # $data_location/$todo_pre_list_file
# }