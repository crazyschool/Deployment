#!/bin/bash

# Install (or reinstall to update!) the controller on a fresh raspbian install
#
# If you want to prevent fs resize on first raspbian boot,
# remove "init=/usr/lib/raspi-config/init_resize.sh" from /boot/cmdline.txt
#
# Usage, to be run on a fresh raspbian image, run either:
#
#     environment/service/install.sh
#     curl https://raw.githubusercontent.com/crazyschool/activity-controller/abd0d72c3bff4a1c9f0529e46f601440b19e9a51/environment/service/install.sh?token=AAA4HYM4SEJAIFDQZ4IYQ625NZI4Q | sh
#
#
# Then ,creating image from SD card and shrink it:
#
# # install pishrink.sh from https://github.com/Drewsif/PiShrink
# wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
# chmod +x pishrink.sh
# sudo mv pishrink.sh /usr/local/bin
# # copy SD to disk
# sudo dd if=/dev/disk2 | pv | dd of=Downloads/crazyschool-raspberrypi-<date>.img bs=4m
# sudo pishrink.sh !$
# scp !$ mien.ch:/var/www/mien.ch/static/crazyschool/.

PKGS=()  # collecting packages names and installiing them at once speeds up the process

###
### System infrastructure
###

sudo touch /boot/ssh
sudo apt-get update && sudo apt-get -y upgrade
PKGS+=(git python3 python3-pip python3-venv) # python infrastructure
PKGS+=(vim screen) # nice to have

# per activity dependencies
PKGS+=(xserver-xorg xserver-xorg-legacy x11-xserver-utils xinit openbox chromium-browser sed) # activity: qcm
PKGS+=(mpg123) # activity: bell

# install all packages at once
sudo apt-get install -y --no-install-recommends ${PKGS[*]}
sudo apt-get autoremove -y
#sudo apt-get clean && sudo rm -r /var/lib/apt/lists/* # cleaning

###
### Dependencies configuration installation, per activity
###

# Activity: QCM
# install GUI (X and chrome browser)
# from https://die-antwort.eu/techblog/2017-12-setup-raspberry-pi-for-kiosk-mode/
# allow starting x as user: https://gist.github.com/alepez/6273dc5220c1c5ec5f3f126e739d58bf
#sudo usermod -a -G tty pi # not needed
sudo cp /etc/X11/Xwrapper.config /etc/X11/Xwrapper.config.orig
sudo sed -i 's/allowed_users=console/allowed_users=anybody/g' /etc/X11/Xwrapper.config
# TODO: fix locale
# TODO in /boot/config.txt:
# - force HDMI video output
# - force JACK audio output
# - raspi memory split ?

###
### Activity-controller software installation
###

# clone git repository, saving the existing in case of failure (eg. invalid credentials)
BASEDIR="/home/pi/crazyschool/activity-controller"
NEWDIR=$BASEDIR-latest
echo "Cloning software into $NEWDIR"
if git clone https://github.com/crazyschool/activity-controller.git $NEWDIR
then
    sudo rm -rf $BASEDIR  # FIXME: some file belong to root in $BASEDIR, it shouldn't: rm: cannot remove '/home/pi/crazyschool/activity-controller/environment/service/__pycache__/__main__.cpython-37.pyc': Permission denied
    mv $NEWDIR $BASEDIR
else
    exit 1
fi
cd $BASEDIR

# FIXME: using dev branch for now
echo "Using dev branch"
git checkout dev

# make venv and install requirements.txt
echo "Creating python venv"
python3 -m venv venv
. venv/bin/activate
pip3 install -r requirements.txt
deactivate

##
## Configuration and system setup
##

# create crazyschool configuration file on /boot partition
sudo cp $BASEDIR/environment/service/crazyschool.ini.example /boot/crazyschool.ini
# TODO: set static IP for first access

# setup systemd services
echo "Setting up systemd services"
sudo rm -rf /etc/systemd/system/crazyschool*
sudo cp $BASEDIR/environment/systemd/services/* /etc/systemd/system/.
sudo systemctl daemon-reload

# enable crazyschool services manager
sudo systemctl start crazyschool.service
sleep 2
echo "Restarting all services to apply update to running software"
sudo systemctl restart crazyschool.*

# all good
echo
echo "Done."

# Write before login message
# TODO: add to /etc/issue ?
#       https://superuser.com/questions/290294/how-to-display-a-message-before-login
