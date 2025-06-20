#!/bin/bash

# For deploying drone simulation, launch script (part 2)
set -e
trap 'echo -e "\nError occurred at line $LINENO: \"$BASH_COMMAND\". Exiting."; read -p "Press Enter to exit..."' ERR

# Run from home directory
./QGroundControl-x86_64.AppImage &

# -------------- Get simulation script
cd Simulation/mavros_ws/src/ros2_px4_stack 
cd scripts
chmod +x sim_trajgen_tmux.py
python3 sim_trajgen_tmux.py