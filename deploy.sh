#!/bin/bash

# For deploying drone simulation, install/deployment script (part 1)
set -e
trap 'echo -e "\nError occurred at line $LINENO: \"$BASH_COMMAND\". Exiting."; read -p "Press Enter to exit..."' ERR

# Do everything from home folder instead
mv * ~/
cd ../
rm -rf acl_sim_deployment
cd ~/

# ------------ Setup Git, ROS2 Humble, vim, terminator, tmux, scipy

# Git
sudo apt update
sudo apt install git -y

# If want SSH
# read -p "Enter your Git username: " git_username
# read -p "Enter your Git email: " git_email

# git config --global user.name "$git_username"
# git config --global user.email "git_email"

# KEY="$HOME/.ssh/id_ed25519"
# if [ ! -f "$KEY" ]; then
#     ssh-keygen -t ed25519 -C "$git_email" -f "$KEY" -N ""
# fi

# eval "$(ssh-agent -s)"
# ssh-add "$KEY"

# echo -e "\n Copy this SSH key to your Git account:\n"
# cat "$KEY.pub"
# read -p "Press Enter when you have done that..."


# ROS2 Humble
locale  # check for UTF-8
sudo apt update && sudo apt install locales -y
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
locale  # verify settings
sudo apt install software-properties-common -y
sudo add-apt-repository universe
sudo apt update && sudo apt install curl -y
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" # If using Ubuntu derivates use $UBUNTU_CODENAME
sudo apt install -y /tmp/ros2-apt-source.deb
sudo apt update
sudo apt upgrade -y
sudo apt install -y ros-humble-desktop ros-dev-tools
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
echo "export INIT_X=0." >> ~/.bashrc
echo "export INIT_Y=0.0" >> ~/.bashrc
echo "export INIT_Z=0.0" >> ~/.bashrc
echo "export INIT_ROLL=0.0" >> ~/.bashrc
echo "export INIT_PITCH=0.0" >> ~/.bashrc
echo "export INIT_YAW=0.0" >> ~/.bashrc
echo "export VEH_NAME=\"SQ01\"" >> ~/.bashrc
echo "export \"MAV_SYS_ID\"=1" >> ~/.bashrc
source ~/.bashrc


# useful stuff
sudo apt install vim terminator tmux python3-scipy -y
python -m pip uninstall -y numpy
python -m pip install --no-cache-dir numpy
python -m pip install numpy==1.25.0


# --------------- Make trajen_ws/src
mkdir Simulation && cd Simulation
mkdir -p trajgen_ws/src && cd trajgen_ws/src
git clone https://github.com/jrached/trajectory_generator_ros2.git
git clone https://github.com/jrached/mission_mode.git
git clone https://github.com/jrached/snapstack_msgs2.git
git clone https://github.com/jrached/behavior_selector2.git
cd ../

# Build packages - order matters!
source /opt/ros/humble/setup.bash
colcon build --packages-select snapstack_msgs2
source install/setup.bash
colcon build --packages-skip snapstack_msgs2
source install/setup.bash


# --------------- Make mavros_ws/src
cd ../ # in Simulation now
mkdir -p mavros_ws/src && cd mavros_ws/src
git clone https://github.com/jrached/ros2_px4_stack.git
cd ros2_px4_stack
git checkout -f class
# turn off sine trajectory
sed -i '106s/True/False/' ros2_px4_stack/track_gen_traj.py

# use correct file path
sed -i '/full_command =/c\            full_command = f"source ~/Simulation/mavros_ws/install/setup.bash && \\source ~/Simulation/trajgen_ws/install/setup.bash && \\source ~/Simulation/bridge_ws/install/setup.bash && {cmd}"' scripts/sim_trajgen_tmux.py

# correct pane 5 with correct file path and to use gz_x500 instead of classic
sed -i '/cd ~\/acl\/px4\/PX4-Autopilot && make px4_sitl gazebo-classic/c\        f"cd ~\/PX4-Autopilot && make px4_sitl gz_x500", # Pane 5' scripts/sim_trajgen_tmux.py

cd ../../ # in mavros_ws now


# Build packages
colcon build
source install/setup.bash


# --------------- Make bridge_ws/src
cd ../ # in Simulation now
mkdir -p bridge_ws/src && cd bridge_ws/src
git clone https://github.com/jrached/mavros.git
sudo apt update
sudo apt install -y ros-humble-mavros
rosdep update
cd ../ # in bridge_ws now
rosdep install --from-paths src --ignore-src -r -y

# Build packages
colcon build
cd ../../ # home


# --------------- Install QGC
sudo usermod -a -G dialout $USER
sudo apt-get remove modemmanager -y
sudo apt install gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl -y
sudo apt install libfuse2 -y
sudo apt install libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor-dev -y

wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage
chmod +x ./QGroundControl-x86_64.AppImage


# --------------- Set up PX4-Autopilot
git clone --recursive https://github.com/PX4/PX4-Autopilot.git
cd PX4-Autopilot
bash ./Tools/setup/ubuntu.sh
cd ../../ # home



# Reboot
echo "Rebooting in 10 seconds... run launch.sh afterwards."
sleep 10
sudo reboot
