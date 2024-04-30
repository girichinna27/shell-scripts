#!/bin/bash

# Title: Set mandatory variables 
# 
# Purpose: This script sets the default values of the variables,
# which are used in the other scripts to prepare Offline Spinnaker package
# Additionally, some functions used by other offline scripts

sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)

olroot=${olroot:-$PWD}
spinver=${1:-$spinver}

#Function checks if a variable is set within the script scope
ifVarsAvailable() {
  if [ $# -eq 0 ]; then
    echo "Error: Pass at least one argument to ${FUNCNAME[0]}()"
    return 1
  fi
  boolVars=true
  for x in $@; do
    if [ ! -z ${!x} ]; then
      echo "Variable '$x' is set with value '${!x}'"
    else
      echo "Error: Variable '$x' is not set";
      boolVars=false;
    fi
  done
  #If boolVars is false, i.e if any variable is empty or null, return with code 2
  if [ $boolVars != true ]; then
    return 2
  fi
}

#Function checks if a commandline program is available on the machine
ifCmdsAvailable() {
  if [ $# -eq 0 ]; then
    echo "Error: Pass at least one argument to ${FUNCNAME[0]}()"
    return 1
  fi
  boolCmds=true
  for x in $@; do
    command -v $x > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "Command '$x' is available" > /dev/null 2>&1
    else
      echo "Error: Command '$x' is not found";
      boolCmds=false;
    fi
  done
  #If boolCmds is false, i.e if any command is missing, return with code 2
  if [ $boolCmds != true ]; then
    return 2
  fi
}

# Add current user to docker group makes 'docker pull' without sudo access
assureDockerAccess() {
  #Executing inside Docker container?
  ISDOCKER=`grep -q  -m 1 'docker\|lxc' /proc/1/cgroup` #Confirms inside Docker container?
  if [ $? -eq 0 ]; then
    #Inside Docker container
    echo "Running inside a Container"
    if ! docker images > /dev/null; then
      echo "Unable to run 'docker images' command. Did you forget to mount /var/run/docker.sock ?"
      echo "Quitting. Make sure 'docker' commands work in your Docker termiminal" 
      exit 1
    fi
  #Executing inside a VM machine
  elif [ "$(systemctl is-active docker)" != "active" ]; then
    echo "It appears Docker service isn't running."
    echo "Quiting. Start the docker service and run this script again to pull images."
    exit 2
  else
    groups $USER | grep docker > /dev/null
    if [ $? -eq 0 ]; then
      echo "The user '$USER' is member of 'docker' group already"
    else
      echo "The user '$USER' is not member of 'docker' group. Adding... (Input sudo password if prompted)"
      sudo usermod -aG docker $USER #Adds user to docker group
      #passwd -d $USER docker #Delete current user from docker group
      #New group does not refelect unless logout & login.
      #If relogin to be avoided, use newgrp or sg. Both launches a new session
      #newgrp docker #Run as non-root
      echo "Exit your (non-root) current session and login again or open a new BASH session to run docker as regular user"
      exit 3
    fi
  fi
}

#Make sure your normal user is able to run docker commands
#assureDockerAccess

showHelp() {
  echo 'Syntax: '
  echo "  $sname <spinnaker-ver>"
  echo '   [OR]'
  echo 'You can set variable like the below on command prompt'
  echo '  export spinver=1.18.9'
  echo 
}
