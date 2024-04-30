#!/bin/bash
# Purpose: Script to prepare Spinnaker BOM files
#
# Notes: In the target Spinnaker halyard, the BOM files should go to ~/.hal/.boms
# Version file is at .boms/bom/<x.y.z>.yml
# Component files are at .boms/<component>/<component-version>
# If Component version files are not available, then default is used from ~/.hal/.boms/<component>/<component>.yml

sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)

source $sdir/spin-includes.sh

olroot=${olroot:-$PWD}
srcroot=$olroot/offlinesrc
tarsdir=$olroot/offlinetars
tmpdir=$olroot/offlinetmp
bomsroot=$srcroot/.boms
verfile=$bomsroot/bom/$spinver.yml
tmpverfile=$srcroot/spin-ver.yml

ifCmdsAvailable yq docker svn gsutil curl wget
if [ $? -ne 0 ]; then
   echo "Make sure the required CLI tools are available and try again"
   echo "You may run the command 'sudo -E ./installUtils.sh' to install required CLI tools"
   exit 1
fi

[ ! -d $tarsdir ] && mkdir -p $tarsdir
[ ! -d $srcroot ] && mkdir -p $srcroot; cd $srcroot

# Download BOM version file. This is the base for driving the rest of the script
[ ! -s $tmpverfile ] && wget -O $tmpverfile https://storage.googleapis.com/halconfig/bom/$spinver.yml
#gsutil cp gs://halconfig/bom/$spinver.yml $verfile

skipBomPull=${skipBomPull:-false}
if [ $skipBomPull == true ]; then
  echo "BOM files pull is skipped"
  exit 2
fi

mkdir -p $bomsroot/bom
cp -vf $tmpverfile $verfile

# By reading BOM ver file, pull BOM content - images and other supporting files
#declare -a services=$(yq r $tmpverfile services | egrep -v ' .*|monit' | sed 's/:$//')
declare -a services=$(yq eval '.services' $tmpverfile | egrep -v ' .*|monit' | sed 's/:$//')
for x in ${services[@]}; do
  echo 
  #xver=$(yq r $tmpverfile services.$x.version) #Value is yielded without quotes
  xver=$(yq eval ".services.$x.version" $tmpverfile) #Value is yielded without quotes
  xname=$(echo $x | sed 's/^"\|"$//g') #Remove the surrounding quotes from the service-name
  echo -e "== $xname \t: $xver"
  mkdir -p $bomsroot/$xname
  gsutil -m cp -R gs://halconfig/$xname/$xver/* $bomsroot/$xname/
done
echo
 
#Additionally download the 'rosco' dependencies i.e the packer files
cd $bomsroot/rosco/
[ -d packer ] && rm -rvf packer/
svn checkout https://github.com/spinnaker/rosco/trunk/rosco-web/config/packer
rm -rf ./packer/.svn
cd ./packer
wget https://raw.githubusercontent.com/spinnaker/rosco/master/rosco-web/config/rosco.yml
cd $srcroot

#Update component version with local: prefix
sed -i -e  '/commit/{n;s/version: /version: local:/;}' $verfile
#Update Spinnaker version with local: prefix
sed -i "s/^version: /version: local:/" $verfile

echo "BOM files are here $PWD/.boms"

if [ "$skipBomTar" != true ]; then
  echo "Creating $srcroot/spin-boms.tar.tz"
  tar -cvzf spin-boms.tar.gz .boms 

  [ -f $srcroot/spin-boms.tar.gz ] && mv -v $srcroot/spin-boms.tar.gz $tarsdir/
  echo "BOM tar file is here: $tarsdir/spin-boms.tar.gz"
fi

echo "DONE - Spinnaker BOM !!!"
