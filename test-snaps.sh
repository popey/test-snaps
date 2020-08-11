#!/bin/bash
# Script to automate setup, install of snaps and running.
# Script will do the following:-
#  - Make sure we're in an X11 session (wayland not supported)
#  - Install snapd and scrot (for taking screenshots) using whatever package manager
#  - Determine distribution being run on, for logging and screenshot naming
#  - Double check snapd is installed and works, and switch to the beta channel
#  - Install a configurable list of snaps
#  - Take a reference screenshot (of the file manager) for theme comparison
#  - Launch each snap in turn
#    - Launch the snap
#    - Wait a while for it to launch (in a VM this may take a little time)
#    - Prompt the user to get the screen ready for a screenshot
#      (user should open an approiate dialog)
#      (user should press [enter] then switch back to the application)
#    - After a configurable delay, a screenshot is taken into $SCREENSHOT_PATH
#  - Capture some version stamps
#
# At the end, the user should copy the screenshots and logs from $SCREENSHOT_PATH off to
# another machine   

strict_snaps=(firefox chromium okular gnome-system-monitor nextcloud lxd)
classic_snaps=(skype pycharm-community slack microk8s multipass snapcraft)

# Do we take screenshots or not?
SCREENSHOTS=0
# What channel to we get the core and core18 snap from
CORECHANNEL="--beta"
# Number of seconds we wait for the app to start before we prompt the user to take a screenshot
APP_START_WAIT=10
# Number of seconds we wait after user presses [enter] before taking the screenshot
SCREENSHOT_DELAY=5
# Number of seconds we wait between checking for unattended-upgrades running in the background
UUWAIT=5
SCREENSHOT_PATH=$HOME/Screenshots
mkdir -p $SCREENSHOT_PATH

check_for_x11 () {
	echo "**** Check we're in an X11 session"
    if [ "$XDG_SESSION_TYPE" = "wayland" ];
    then
	    echo "**** Wayland is out of scope for these tests"
	    echo "**** Restart under X11"
	    exit 4
	fi
}

install_deps () {
	echo "**** Determine package manager"
	APT=$(which apt)
	DNF=$(which dnf)
	YUM=$(which yum)
	EOPKG=$(which eopkg)
	PACMAN=$(which pacman)
	ZYPPER=$(which zypper)
	UPDATECMD=""
	PREINSTALLCMD=""
	INSTALLCMD=""
	POSTINSTALLCMD=""
	if  [ "$ZYPPER" ];
	then
		echo "**** zypper found, assuming suse"
		PREINSTALLCMD="sudo zypper -n addrepo --refresh http://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_15.0/ snappy"
		UPDATECMD="sudo zypper -n update"
		INSTALLCMD="sudo zypper -n install scrot snapd"
		POSTINSTALLCMD="sudo systemctl enable --now snapd && sudo systemctl start snapd"
	elif [ "$EOPKG" ];
	then
		echo "**** eopkg found, assuming Solus"
                UPDATECMD="sudo eopkg -y update-repo"
                INSTALLCMD="sudo eopkg -y install scrot snapd"
    elif [ "$YUM" ];
    then
		echo "**** zypper found, assuming suse"
		PREINSTALLCMD="sudo yum install epel-release"
		UPDATECMD="sudo yum update"
		INSTALLCMD="sudo yum install snapd"
		POSTINSTALLCMD="sudo systemctl enable --now snapd && sudo systemctl start snapd && sudo ln -s /var/lib/snapd/snap /snap"
	elif [ "$DNF" ]; 
	then
		echo "**** dnf found, assuming rpm based distro"
		UPDATECMD="sudo dnf -y update"
		INSTALLCMD="sudo dnf -y install scrot snapd"
	elif [ "$PACMAN" ];
	then
		echo "**** pacman found, assuming arch"
		UPDATECMD="sudo pacman -Syu --noconfirm"
		INSTALLCMD="sudo pacman -Sy --noconfirm scrot snapd"
		POSTINSTALLCMD="sudo systemctl start snapd"
	elif [ "$APT" ]; 
	then 
		echo "**** apt found, assuming deb based distro"
		UPDATECMD="sudo apt update"
		INSTALLCMD="sudo apt install -y scrot snapd"
		echo "**** Waiting for unattended upgrade in the background"
		while [ "$(ps aux | grep unattended-upgrades | grep -v grep )" ];
		do
		  sleep $UUWAIT
		  echo -n .
		done
	else
		echo "**** Don't know how to install scrot and snapd here"
		exit 2
	fi
	echo "**** Running pre-install commands"
	$PREINSTALLCMD
	echo "**** Running update commands"
	$UPDATECMD
	if [ $? -eq 0 ];
	then
		echo "**** Running install commands"
		$INSTALLCMD
		if [ $? -eq 0 ];
		then
			echo "**** Running post-install commands"
			$POSTINSTALLCMD
			if [ $? -eq 0 ];
			then
				echo "**** Finished installing packages"
			fi
		fi
	else
	    echo "**** Failed to run $UPDATECMD"
		exit 1
	fi
	echo "**** Sleeping for a few seconds, waiting for snapd to settle"
	sleep 10
}

detect_distribution () {
	NAME="$(grep ^NAME /etc/os-release | cut -d'=' -f2-)"
	VERSION="$(grep ^VERSION_ID /etc/os-release | cut -d'=' -f2-)"
	DIST="$(echo $NAME-$VERSION | tr ' ' '_' | tr -d '\"' | tr -d '\/')"
	if [ $? -eq 0 ];
	then
		echo "**** Possibly running on:" $DIST
	else
	    echo "**** Couldn't determine distribution from lsb_release -d. Halp!"
		exit 3
	fi
}

check_for_snapd () {
	SNAP_VER=$(snap version)
	if [ $? -eq 0 ];
	then
		echo $SNAP_VER
	else
	    echo "**** Snap command not available. Install it first"
		exit 5
	fi
}

check_for_snap_dir () {
	if [ -d "/snap" ]; then
		echo "**** /snap directory exists"
	else
		echo "**** /snap directory doesn't exist, fixing"
		sudo ln -s /var/lib/snapd/snap /snap
	fi
}

switch_to_beta_core () {
	echo "**** Switch to $CORECHANNEL core"
	snap info core | grep ^installed
	if [ $? -eq 0 ];
	then
		echo "**** core installed, refreshing to beta channel"
		sudo snap refresh core $CORECHANNEL
	else
		echo "**** core not installed, installing from beta channel"
		sudo snap install core $CORECHANNEL
	fi
	echo "**** Switch to $CORECHANNEL core"
	snap info core18 | grep ^installed
	if [ $? -eq 0 ];
	then
		echo "**** core installed, refreshing to beta channel"
		sudo snap refresh core18 $CORECHANNEL
	else
		echo "**** core not installed, installing from beta channel"
		sudo snap install core18 $CORECHANNEL
	fi
}

screenshot () {
	# wait a few seconds so the application starts
	# and calms down spewing out to the console
	sleep $APP_START_WAIT
	if [ "$SCREENSHOTS" -eq "1" ];
	then
		echo "**** Arrange the window with what you wish to show then"
		read -p "**** press Enter, 5 seconds later we take a screenshot"
	  	scrot --delay $SCREENSHOT_DELAY -c -q 100 "$SCREENSHOT_PATH/$DIST-$1-%Y-%m-%d.png"
		if [ $? -eq 0 ];
		then
			echo "**** Screenshot of $1 on $DIST taken"
		else
			echo "**** No screenshot taken"
			exit 6
		fi
	fi
	read -p "**** press Enter to continue"
}

install_strict_snap () {
	echo "**** Installing $1"
	sudo snap install $1
}

install_classic_snap () {
	echo "**** Installing $1 (classic)"
	# multipass is only in beta
	if [ "$1" == "multipass" ];
	then
		sudo snap install $1 --classic --beta
	else
		sudo snap install $1 --classic
	fi
}

install_all_snaps () {
	for i in ${strict_snaps[@]}; do
		install_strict_snap $i
	done

	for i in ${classic_snaps[@]}; do
		install_classic_snap $i
	done
}

take_reference_screenshot () {
	if [ "$SCREENSHOTS" -eq "1" ];
	then
		echo "**** Taking reference screenshot of non-snapped application"
		echo "**** Open the file picker dialog and screenshot that"
		snap list > ~/snaps.txt
		xdg-open ~/snaps.txt &
		screenshot reference
	fi
}

test_all_snaps () {
	for i in ${strict_snaps[@]}; do
		echo "**** Starting $i"
		if [ "$i" = "lxd" ];
		then
			sudo /snap/bin/lxd init --auto --storage-backend dir
			sudo sudo usermod --append --groups lxd $USER
			newgrp lxd
			/snap/bin/lxc launch ubuntu:18.04
			/snap/bin/lxc list
		elif [ "$i" = "nextcloud" ];
		then
			xdg-open http://localhost/
		elif [ "$i" = "node-red" ]; 
		then
			xdg-open http://localhost:1880/
		elif [ "$i" = "hello-world" ]; 
		then
			snap run $i.evil &
		else
			snap run $i &
		fi
		screenshot $i
	done
	for i in ${classic_snaps[@]}; do
		if [ "$i" = "multipass" ];
		then
			multipass list
			multipass launch bionic
			multipass list
		elif [ "$i" = "snapcraft" ]; 
		then
			olddir=$(pwd)
			mkdir -p ~/snapcraft_test
			cd ~/snapcraft_test
			snap run $i init
			snapcraft
			snapcraft --use-lxd
			cd $olddir
		elif [ "$i" = "microk8s" ];
		then 
			snap run microk8s.enable istio
			snap run microk8s.kubectl get all --all-namespaces
		else
			echo "**** Starting $i"
			snap run $i &
			screenshot $i
		fi
	done
}

save_debug_info () {
	snap version > $SCREENSHOT_PATH/snap_version
	snap info core > $SCREENSHOT_PATH/snap_info_core
	snap list --all > $SCREENSHOT_PATH/snap_list_all
    snap debug confinement > $SCREENSHOT_PATH/snap_debug_confinement
    snap debug sandbox-features > $SCREENSHOT_PATH/snap_debug_sandbox-features
	cp /etc/os-release $SCREENSHOT_PATH/os-release
}

check_for_x11
install_deps
detect_distribution
check_for_snapd
check_for_snap_dir
switch_to_beta_core
install_all_snaps
take_reference_screenshot
test_all_snaps
save_debug_info

echo "**** Done"
echo "**** Don't forget to copy everything from $SCREENSHOT_PATH"
