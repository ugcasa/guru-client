# ujo.guru giocon tool kit launcher
# Runs every time terminal is opened

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Juha Palm ujo.guru 2019

### main functions

gio.disable () {
	if [ -f "$HOME/.gururc" ]; then 
		mv -f "$HOME/.gururc" "$HOME/.gururc.disabled" 
		echo "giocon.client disabled"
	else		
		echo "disabling failed"
	fi	
}


gio.uninstall () {	 
	if [ -f "$HOME/.bashrc.giobackup" ]; then 
		mv -f "$HOME/.bashrc.giobackup" "$HOME/.bashrc"		
		mv -f "$HOME/.profile.giobackup" "$HOME/.profile"				
		rm -f "$HOME/.gururc"
		dconf load /org/cinnamon/desktop/keybindings/ < $HOME/.kbbind.backup.cfg		
		sudo rm -fr /opt/gio
		rm -fr "$HOME/.config/gio"
		echo "giocon.client uninstalled"
	else		
		echo "uninstall failed"
	fi	
}


gio.connect () {
	#echo "TODO: ssh ujo.guru -p2010.. got parameters: $@"
	case "$1" in
		status)
			echo "not connected"
			;;
			*)
			echo "TODO: non functional. got parameters: $@"
	esac	
}

gio.status () {
	printf  "\e[1mTimer\e[0m: $(gio.timer status)\n" 
	printf  "\e[1mConnect\e[0m: $(gio.connect status)\n" 
}

export -f gio.disable
export -f gio.uninstall
export -f gio.connect
export -f gio.status

### Notes

gio.subl () {
	# Open sublime project 
	if ! [ -z "$1" ]; then 
		subl --project $HOME/Dropbox/Notes/casa/project/$1.sublime-project -a 
		subl --project $HOME/Dropbox/Notes/casa/project/$1.sublime-project -a #$2 $3 $3 $4 $5 $6 $7 $8 $9
	else
		echo "enter project, and optional file name"
	fi
}


gio.dozer () {
	cfg=$HOME/.config/guru.io/noter.cfg
	[[ -z "$2" ]] && template="ujo.guru.004" || template="$2"
	[[ -f "$cfg" ]] && . $cfg || echo "cfg file missing $cfg" | exit 1 
	pandoc "$1" --reference-odt="$notes/$USER/$template-template.odt" -f markdown -o  $(echo "$1" |sed 's/\.md\>//g').odt
}

export -f gio.subl
export -f gio.dozer


### youtube player (mpsyt) controls

play.by () {	
	command="mpsyt set show_video True, set search_music True, /$@, 1-, q"
	gnome-terminal --geometry=80x28 --zoom=0.75 -- /bin/bash -c "$command; exit; $SHELL; "
}


play.bg () {		
	command="for i in {1..3}; do mpsyt set show_video False, set search_music True, //$@, "'$i'", 1-, q; done"	
	gnome-terminal --geometry=80x28 --zoom=0.75 -- /bin/bash -c "$command; exit; $SHELL; "
}


play.video () {	
	command="mpsyt set show_video True, set search_music False, /$@, 1-, q"
	gnome-terminal --geometry=80x28 --zoom=0.75 -- /bin/bash -c "$command; exit; $SHELL; "
}


play.upgrade () {	
	sudo -H pip3 install --upgrade youtube_dl
}

export -f play.bg
export -f play.by
export -f play.video
export -f play.upgrade
