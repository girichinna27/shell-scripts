#!/bin/bash

# Purpose: Installs commandline utils necessary to prepare offline Spinnaker package bundle
# This script is called in a Dockerfile (root as current user) where the base image is Ubuntu
# Asummed that Internet is available

sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)

echo "Installing Binaries - started"
mkdir /tmp/scripts-wd && cd /tmp/scripts-wd

echo "Current directory is : $PWD"

# Update Ubuntu Software repository
apt update && apt upgrade -y

# Install basic utils - curl, wget, jq, zip+unzip, tree, vim, svn, docker
apt install -y curl wget jq tree zip unzip
apt install -y vim
apt install -y subversion
apt install -y docker.io
apt install -y podman #Podman, an alternate to Docker

# curl/wget used to download files.
# jq - parses json files
# svn is used for pulling a directory from GitHub repo
# docker - pulls and saves docker images
# yq - parses yaml files
# gsutil - downloads files from Google Storage (GS)
# helm - templatatizes helm chart for parsing yaml files
# kubectl - CLI to interact with a K8s cluster
# awsli, azcli, gsutil - Cloud CLI tools

## Approx size of the packages
# wget 1012 kB, jq 1062 kB, tree 115 kB, zip/unzip 1231 kB
# curl 11.2 MB, vim 70.6 MB, docker 405 MB, subversion(svn) 10.3 MB
# kubectl 50 MB, helm3 50 MB
# gsutil(google-cloud-sdk) 1.4G, 
# awscliv2.zip 55M, aws 208 MB,
# azure-cli 65.3 MB   

# Install yq - a yaml parser
#if command -v yq > /dev/null; then return; fi
echo 'Installing yq CLI tool...'
# https://mikefarah.gitbook.io/yq/#install
#VERSION="3.4.1"
VERSION="v4.10.0"
BINARY="yq_linux_amd64"
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O yq
chmod +x yq
mv yq /usr/local/bin/yq

# Install Gsutil (Google Cloud CLI)
echo 'Installing gsutil CLI tool...'
# echo 'For detailed instruction, visit - https://cloud.google.com/storage/docs/gsutil_install for instruction on installing GSUtil'
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-424.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-424.0.0-linux-x86_64.tar.gz -C /opt/
/opt/google-cloud-sdk/install.sh --usage-reporting=false --path-update=true --quiet
#ln -s /opt/google-cloud-sdk/bin/gsutil /usr/bin/gsutil

#wget https://dl.google.com/dl/cloudsdk/channels/rapid/install_google_cloud_sdk.bash
# bash install_google_cloud_sdk.bash --install-dir=/opt --disable-prompts
#[ -d $HOME/.config ] && chown -R `id -un`: $HOME/.config
#[ -d $HOME/.config ] && chown -R $USER: $HOME/.config
#ln -s /opt/google-cloud-sdk/bin/gsutil /usr/bin/gsutil
# echo 'Run "gcloud init" to login to Google if you need to work with GCloud'
# echo 'Login is not required for copying from public storage using "gsutil cp "'

# Install AWS CLI 
echo 'Installing aws CLI tool...'
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install #Default installation to /usr/local/aws-cli, a symlink created in /usr/local/bin
aws --version

# Install Azure-CLI (az)
curl -sL https://aka.ms/InstallAzureCLIDeb | bash


# Install kubectl (Kubernetes Client CLI)
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
# or  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.7.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
cp /usr/local/bin/kubectl /usr/local/bin/kubectl-orig
kubectl version --short

# Install kubectl (Kubernetes Client CLI)
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
# or  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.7.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
cp /usr/local/bin/kubectl /usr/local/bin/kubectl-orig
kubectl version --short

# Install OC (OpenShift Client CLI)
wget -O oc-linux.tar.gz yq https://github.com/okd-project/okd/releases/download/4.12.0-0.okd-2023-04-16-041331/openshift-client-linux-4.12.0-0.okd-2023-04-16-041331.tar.gz
tar -xvf oc-linux.tar.gz
mv kubectl /usr/local/bin/kubectl
mv oc /usr/local/bin/oc
oc version

# Install Helm3, a K8s manifest packager
echo 'Installing Helm client CLI tool...'
curl -fsSL -o get-helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get-helm.sh
./get-helm.sh

# Deleting tmp directory used for files download, otherwise goes into the image
cd ~ # Go from /tmp/scripts-wd to $HOME dir
rm -rf /tmp/scripts-wd

echo "Installing binaries - Done"

