#!/bin/bash
# Script to prepare Spinnaker offline package including BOM files, Docker images

sname=${sname:-$(basename $BASH_SOURCE)}
sdir=${sidr:-$(cd `dirname $BASH_SOURCE` && pwd)}
source $sdir/spin-includes.sh

spinver=${1:-$spinver}
if [ -z $spinver ]; then
    echo "ERROR: Spinnaker version is not supplied"
    showHelp
    exit 1
fi

showScriptSettings() {
  echo SCRIPT SETTINGS ARE ...
  echo Exec Base Directory : $olroot
  echo Spinnaker Version : $spinver
  echo
}
showScriptSettings

#exit
olroot=${olroot:-$PWD}
tarsdir=$olroot/offlinetars
srcroot=$olroot/offlinesrc
tmpdir=$olroot/offlinetmp

[ ! -d $tarsdir ] && mkdir -p $tarsdir
[ ! -d $srcroot ] && mkdir -p $srcroot
[ ! -d $tmpdir ] && mkdir -p $tmpdir

ifCmdsAvailable curl wget vim svn yq docker gsutil
#ifVarsAvailable spinver olroot dcr 
ifVarsAvailable spinver olroot 

#Ensure current user has to access to run 'docker pull'
assureDockerAccess

#Download Helm chart
skipChartDownload=${skipChartDownload:-false}
if [ $skipChartDownload != true ]; then
  echo -e "\n\n-----> Fetching Spinnaker Helm chart - ${helmcharturl}"
  cd $srcroot; curl -LO ${helmcharturl}
  chartfile=$(basename $helmcharturl)
  echo "-----> Running 'helm template' on ${chartfile} to generate manifest (for getting image list)"
  # helm template <release> <chart> --output-dir <local-directory>
  helm template opsmx ${chartfile} --output-dir helmdir
  echo "  --> Grep-ing manifests files for image list"
  grep -ir 'image:' helmdir | grep -v "[#;]" | sed "s/.*image: //" | tr -d \'\" | sort | uniq > helm-images.txt
  echo "  --> Grep completed. Image list is saved to helm-images.txt"
  cp -f $srcroot/$chartfile $tarsdir
fi

# Download BOM files
skipGetBomsScript=${skipGetBomsScript:-false}
if [ $skipGetBomsScript != true ]; then
  cd $sdir; echo -e "\n\n-----> netspin-getbom.sh"
  bash $sdir/netspin-getbom.sh 
  [ -f $srcroot/spin-boms.tar.gz ] && mv -v $srcroot/spin-boms.tar.gz $tarsdir/
fi

# Download Docker images
skipGetImagesScript=${skipGetImagesScript:-false}
if [ $skipGetImagesScript != true ]; then
  cd $sdir; echo -e "\n\n-----> netspin-getimages.sh"
  rm -rfv $srcroot/spin-images.tar.gz $srcroot/spin-images
  bash $sdir/netspin-getimages.sh
  [ -f $srcroot/spin-images.tar.gz ] && mv $srcroot/spin-images.tar.gz $tarsdir/
fi

copySupportiveScripts() {
  cp $sdir/*.sh $olroot/
  cp $sdir/*.var $olroot/
  cp $sdir/*.yml $olroot/
}
[ $sdir != $olroot ] && copySupportiveScripts

#Create final tar.gz from parent directory of $olroot
tarFinalPkg() {
  tarSrc=${PWD##*/} #basename $PWD
  tarFile=$tarSrc
  #Usually tarFile name is the parent directory name of the netspin-pkgoffline.sh file 
  #We are overidding it with specific name for the airgapped package - airgap-bundle.tar
  tarFile=airgap-bundle
  tarDir=${PWD%/*} #dirname $PWD #ParentDir of $PWD
  cd ..
  echo "PWD dir : $PWD"
  echo "Creating $PWD/$tarFile.tar"
  set -x
  #tar --exclude="spin-scripts/offlinesrc*" --exclude="spin-scripts/offlinetmp" --transform "s/.*spin-scripts/airgap-isd/" -cvf tarFile1.tar spin-scripts
  #In file content list, change the file path prefix from $tarSrc (i.e spin-scripts) to airgap-bundle
  tar --exclude="$tarSrc/offlinesrc*" --exclude="$tarSrc/offlinetmp" --transform "s/.*$tarSrc/$tarFile/" -cvf $tarFile.tar $tarSrc
  set +x
  echo "All-in-one bundle file $PWD/$tarFile.tar is ready."
  mv -v $PWD/$tarFile.tar /tmp/hostdir/
  echo "The bundle file $PWD/$tarFile.tar is moved to /tmp/hostdir/"
  echo "NOTE: Since this is a container directory mounted to Host machine, the bundle is still available in the Host even when you exit the container."
  echo "Use this file for your offline installation"
}
cd $olroot
skipFinalTarPkg=${skipFinalTarPkg:-false}
[ $skipFinalTarPkg != true ] && tarFinalPkg

echo "DONE - ALL !!!"
