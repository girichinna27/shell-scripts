#!/bin/bash
# Purpose: This script contains pre-package validations/install CLI functions to package/install offline Spinnaker
#
# Notes: Run this script as root user or using sudo

sname=$(basename $BASH_SOURCE)

showHelp() {
  echo 'Syntax: '
  echo "  sudo -E ./$sname olspin-mc(or)netspin-mc"
  echo 
}

if [ "$EUID" -ne 0 ]; then 
  echo "The script '$sname' is invoked by a non-root user. Please run using 'sudo'"
  showHelp
  exit 255
fi

if [ $# -eq 0 ]; then
  echo "Error: No argument is supplied. Try again"
  showHelp
  exit 1
else
  mc=$1
fi

checkNetConnectivity() {
  netavailable=false
  if wget -q --tries=10 --timeout=20 --spider http://google.com ; then
    netavailable=true
    echo 'Internet connectivity is available on this machine'
  else
    echo 'Internet connectivity is not available on this machine'
  fi
}
netavailable=false; checkNetConnectivity

#If sudo version is less than 1.8.8, then sudo --preserv-env wont work. 
#If needed, upgrade sudo
upgradeSudo() {
  sudodoubledash=false
  if sudo --help &> /dev/null ; then
    sudodoubledash=true
    echo 'Sudo meets minimum required version 1.8.8'
  else
    echo "Sudo doesn't meet minimum required version 1.8.8, needs upgrade"
    echo 'Installing upgrading sudo...'
    if command -v apt-get > /dev/null; then
      apt-get install -y sudo
    elif command -v yum > /dev/null; then
      yum install -y sudo
    fi

  fi
}
#upgradeSudo
export PATH=$PATH:/usr/local/bin:$HOME/bin:/home/$SUDO_USER/bin
echo "Make sure PATH includes /usr/local/bin directory"
echo PATH $PATH

# Install vim, wget and curl
installBasics() {
  #echo 'Installing vim, wget, curl CLI tools...'
  #Install wget
  if ! command -v wget > /dev/null; then
    echo 'Installing wget...'
    if command -v apt-get > /dev/null; then
      apt-get install -y wget
    elif command -v yum > /dev/null; then
      yum install -y wget
    fi
  fi 

  #Install vim
  if ! command -v vim > /dev/null; then
    echo 'Installing vim...'
    if command -v apt-get > /dev/null; then
      apt-get install -y vim
    elif command -v yum > /dev/null; then
      yum install -y vim
    fi
  fi 

  #Install curl
  if ! command -v curl > /dev/null; then
    echo 'Installing curl...'
    if command -v apt-get > /dev/null; then
      apt-get install -y curl
    elif command -v yum > /dev/null; then
      yum install -y curl
    fi
  fi 
}

# Install yq
installYqOld() {
  #Even if yq is available, its not visible inside sudo
  if snap list | grep yq > /dev/null ; then return; fi
  if command -v yq > /dev/null; then return; fi
  echo 'Installing yq CLI tool...'
  #If snap is not available, install it
  if ! command -v snap > /dev/null; then
    echo "Snap is not available, installing it"
    # https://mikefarah.gitbook.io/yq/
    yum install -y epel-release
    yum install -y snapd
    systemctl enable --now snapd.socket
    ln -s /var/lib/snapd/snap /snap
    until snap list > /dev/null; do sleep 10 ; done
  fi
  snap install yq
  echo "Re-login or open a new BASH session to run refresh yq installation"
  ln -s /var/lib/snapd/snap/bin/yq /usr/bin/yq
}

installYq() {
  if command -v yq > /dev/null; then return; fi
  echo 'Installing yq CLI tool...'
  # https://mikefarah.gitbook.io/yq/#install
  #VERSION="3.4.1"
  VERSION="v4.10.0"
  BINARY="yq_linux_amd64"
  wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O yq
  chmod +x yq
  mv yq /usr/local/bin/yq
}

# Install Subversion
installSvn() {
  if command -v svn > /dev/null; then return; fi
  echo 'Installing Subversion(svn) client CLI tool...'
  if command -v apt-get > /dev/null; then
    apt-get install -y subversion
  elif command -v yum > /dev/null; then
    yum install -y subversion
  fi
}

# Add current user to docker group makes 'docker pull' without sudo access
assureDockerAccess() {
  groups $SUDO_USER | grep docker > /dev/null
  if [ $? -ne 0 ]; then
    echo "The user '$SUDO_USER' is not member of 'docker' group. Adding..."
    usermod -aG docker $SUDO_USER #Adds user to docker group
    #gpasswd -d $SUDO_USER docker #Delete current user from docker group
    #New group does not refelect unless logout&login.
    #If relogin to be avoided, use newgrp or sg. Both launches a new session
    #newgrp docker #Run as non-root
    echo "Exit your (non-root) current session and login again or open a new BASH session to run docker as regular user"
  fi
}

# Install Docker
installDocker() {
  if command -v docker > /dev/null; then assureDockerAccess; return; fi
  echo 'Installing Docker client CLI tool...'
  # https://docs.docker.com/engine/install/centos/
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  usermod -aG docker $SUDO_USER
}

# Install Helm 3
installHelm() {
  if command -v helm > /dev/null; then return; fi
  echo 'Installing Helm client CLI tool...'
  curl -fsSL -o get-helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod +x get-helm.sh
  ./get-helm.sh
}

# Install Gsutil
installGsutil() {
  if command -v gsutil > /dev/null; then return; fi
  echo 'Installing gsutil CLI tool...'
  echo 'For detailed instruction, visit - https://cloud.google.com/storage/docs/gsutil_install for instruction on installing GSUtil'
  # curl https://sdk.cloud.google.com | bash
  # exec -l $SHELL
  # gcloud init

  SUDOHOME=$(eval echo ~$SUDO_USER)
  cd $SUDOHOME
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/install_google_cloud_sdk.bash
  bash install_google_cloud_sdk.bash --install-dir=/opt --disable-prompts
  [ -d $HOME/.config ] && chown -R $USER: $HOME/.config
  cp -rv $HOME/.config $SUDOHOME/
  chown -R $SUDO_USER: $SUDOHOME/.config
  
  ln -s /opt/google-cloud-sdk/bin/gsutil /usr/bin/gsutil
  #echo 'export PATH=$PATH:/opt/google-cloud-sdk/bin' >> ~/.bashrc
  #exec -l $SHELL
  echo 'Run "gcloud init" to login to Google if you need to work with GCloud'
  echo 'Login is not required for copying from public storage using "gsutil cp "'
}

# Install CLI tools depending on the type of machine used in Airgapped-Packaging/Installing
case $mc in
  netspin-mc)
    if [ $netavailable == false ]; then
      echo 'Error. Without internet connectivity, Offline package cannot be prepared'
      exit 3
    fi
    echo "Verifying and installing pre-required CLIs for Packaging machine (netspin-mc)"
    installBasics
    installYq
    installSvn
    installDocker
    installGsutil
    echo "--- Done"
    ;;
  olspin-mc)
    if [ $netavailable == false ]; then
      echo 'This machine does not have internet connectivity. Do install pre-required CLIs for K8s-connected machine (olspin-mc)'
      echo 'You may check the pages below from an internet connected machine for instructions on installing CLI tools'
      echo '.. Helm :  https://helm.sh/docs/intro/install/'
      echo '.. Docker : https://docs.docker.com/engine/install/'
      echo '.. Yq : https://mikefarah.gitbook.io/yq/'
      exit 3
    fi

    echo "Verifying and installing pre-required CLIs for K8s-connected machine (olspin-mc)"
    installHelm
    installBasics
    installYq
    installDocker
    echo "--- Done"
    ;;
  *)
    echo "Error: Invalid option to install CLI commands"
    showHelp
    exit 1  
    ;;
esac

#Call every 'install' functions available in this file - functions have 'install' prefix
#declare -a funcs=($(declare -F | awk '{print $3}' | grep -v '_' | grep -ie "^install"))
#for x in ${funcs[*]}; do
#  echo "Executing - $x"
#  $x
#done
