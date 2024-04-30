#!/bin/bash
# Script to push Docker images from tar files to private registry

sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)

source $sdir/spin-includes.sh

spinver=${1:-$spinver}
if [ -z $spinver ]; then
    echo "ERROR: Spinnaker version is not supplied"
    showHelp
    exit 1
fi

# Private Docker Container Registry (dcr)
dcr=${1:-$dcr}
if [ -z $dcr ]; then
    echo "ERROR: Private Docker registry is not supplied"
    echo "Set the registry like the below..."
    echo "   export dcr=quay.io/sagayd"
    exit 2
fi

olroot=${olroot:-$PWD}
tarsdir=$olroot/offlinetars
srcroot=$olroot/offlinesrc
tmpdir=$olroot/offlinetmp
dcr=${1:-$dcr}

netimgfile='netspin-images2pull.yml'
imgfile='olspin-images.yml'
dockerloadlog=$olroot/dockerload.log

ifCmdsAvailable docker tee curl wget
if [ $? -ne 0 ]; then
   echo "Make sure the required CLI tools are available and try again"
   exit 1
fi

createRequiredDirs() {
  [ ! -d $tarsdir ] && mkdir -p $tarsdir
  [ ! -d $srcroot ] && mkdir -p $srcroot
  [ ! -d $tmpdir ] && mkdir -p $tmpdir
}
createRequiredDirs

# Create a Helm Values.yml file particularly for Image overrides
setupHelmValuesOfImagesoverrides() {
  dependenciesoverridefile=$olroot/dependencies-and-overrides-pull.yml
  tmpoverridefile=$tmpdir/images-overrides-tmp.yml
  helmimgoverridefile=$olroot/images-overrides_values.yaml
  
  MATCHTXT='overrides:'
  #Delete lines preceding $MATCHTXT, blank lines, commented lines and key-only lines (like dependencies:)
  sed -e "1,/$MATCHTXT/d" -e '/^\s*$/d' -e '/^\s*#/d' -e '/.*:\s*$/d' -e 's/^\s*//' \
      $dependenciesoverridefile > $tmpoverridefile

  echo $tmpoverridefile
  cat $tmpoverridefile
 
  if [ ! -s $tmpoverridefile ]; then
    echo "There are no images to override"
    return 1
  else
    echo "As there are images to override, preparing Helm images-verride file $helmimgoverridefile"
    echo '#Image Overrides for Spinnaker services' > $helmimgoverridefile
    echo 'halyard:' >> $helmimgoverridefile
    echo '  additionalServiceSettings:' >> $helmimgoverridefile
  fi
  
  while IFS= read -r line; do
     echo "$line"
     #Sample $line
     #gate: docker.io/devopsmx/ubi8-oes-gate:version-1.14.0
     #First field, removed the trailing colon (:)
     msvc=$(echo $line | awk -F ": " '{print $1}')
     #echo $msvc
     regimg=$(echo $line | awk -F ": " '{print $2}')
     echo skipPrivateRegistry $skipPrivateRegistry
     if [ $skipPrivateRegistry == true || -z $dcr ]; then
       echo "    $msvc.yml:" >> $helmimgoverridefile
       echo "      artifactId: $regimg" >> $helmimgoverridefile
       echo "      artifactId: $regimg"
     else
       imgname=$(basename $regimg)
       privimg=$dcr/$imgname
       echo "    $msvc.yml:" >> $helmimgoverridefile
       echo "      artifactId: $privimg" >> $helmimgoverridefile
     fi
  done < $tmpoverridefile
  return 0  
}
skipHelmValuesSetup=${skipHelmValuesSetup:-false}
[ $skipHelmValuesSetup != true ] && setupHelmValuesOfImagesoverrides


# Create list of images to be pushed to private regsitry based on the pullImagesList
createPushList() {
#  netimgfile='netspin-images2pull.yml'
#  imgfile='olspin-images.yml'
  echo "Creating $imgfile file with push-image list"
  cp -vf $netimgfile $imgfile
  sed -r -e "s|(.+ )(.*?)(/.*)|\1$dcr\3|" -i $imgfile
  echo "--- Content of $imgfile ..."
  cat $imgfile
  echo "---"
}
cd $olroot
skipCreatingPushList=${skipCreatingPushList:-false}
[ $skipCreatingPushList != true ] && createPushList


# Untar spin-images.tar.gz which holds the docker images
untarImages() {
  echo "Untarring spin-images.tar.gz" 
  tar -xzvf spin-images.tar.gz
  if [ $? -eq 0 ]; then echo "Untar of spin-images.tar.gz is successful"; fi
#  [ ! -d $srcroot ] && mkdir -p $srcroot
#  mv spin-images $srcroot/
}
cd $tarsdir
skipUntaringImages=${skipUntaringImages:-false}
[ $skipUntaringImages != true ] && untarImages

# Load every docker image into the Docker cache from their tar file
loadImages() {
  cat /dev/null > $dockerloadlog
  echo "Loading Docker images from $PWD directory"
  for x in spin-images/*.tar; do
    echo "-- $x"
    docker load -i $x | tee -a $dockerloadlog
    #Loaded images automatically gets deleted if enough space is unavailable
  done
  echo "Done - Docker Load !!!"
  cd ..
}
cd $tarsdir
skipLoadingImages=${skipLoadingImages:-false}
[ $skipLoadingImages != true ] && loadImages

# Tag the loaded images from tar files with a private registry reference in preparation for pushing
tagImages() {
  echo "Tagging Docker images (private registry entry) using $netimgfile"
  while IFS= read -r line; do
     echo "$line"
     #Sample $line
     #gate: docker.io/devopsmx/ubi8-oes-gate:version-1.14.0
     msvc=$(echo $line | awk -F ": " '{print $1}')
     regimg=$(echo $line | awk -F ": " '{print $2}')
     img=$(basename $regimg)
     imgname=$(echo $img | awk -F ':' '{print $1}')
     imgtag=$(echo $img | awk -F ':' '{print $2}')
     privimg=$dcr/$img
     #echo -e "$regimg \n $img \n $imgname \n $imgtag"
     #echo -e "\n$privimg"
     echo -e "Public Image: $regimg"
     echo -e "Private Image: $privimg"
     docker tag $regimg $privimg
     echo ----
  done < $netimgfile
}
cd $olroot
skipTaggingImages=${skipTaggingImages:-false}
[ $skipTaggingImages != true ] && tagImages

# Push the private registry tagged images into the private registry
pushImages2Registry() {
  echo "===> Pushing Docker images to private registry"
  while IFS= read -r line; do
     echo "$line"
     #Sample $line
     #gate: docker.io/devopsmx/ubi8-oes-gate:version-1.14.0
     msvc=$(echo $line | awk -F ": " '{print $1}')
     regimg=$(echo $line | awk -F ": " '{print $2}')
     img=$(basename $regimg)
     imgname=$(echo $img | awk -F ':' '{print $1}')
     imgtag=$(echo $img | awk -F ':' '{print $2}')
     #echo -e "$regimg \n $img \n $imgname \n $imgtag"
     echo -e "Pushing $regimg \n"
     docker push $regimg
     echo ----
  done < $imgfile
  echo "Done - Pushing Images to Docker registry!!!"
}
cd $olroot
skipImages2Registry=${skipImages2Registry:-false}
[ $skipImages2Registry != true ] && pushImages2Registry

# Clean the Docker images from local images cache
cleanLocalImages() {
  echo "Cleaning Local Docker images using $imgfile"
  while IFS= read -r line; do
     echo "$line"
     #gate: docker.io/devopsmx/ubi8-oes-gate:version-1.14.0
     msvc=$(echo $line | awk -F ": " '{print $1}')
     regimg=$(echo $line | awk -F ": " '{print $2}')
     img=$(basename $regimg)
     imgname=$(echo $img | awk -F ':' '{print $1}')
     imgtag=$(echo $img | awk -F ':' '{print $2}')
     privimg=$dcr/$img
     #echo -e "$regimg \n $img \n $imgname \n $imgtag"
     echo -e "Public Image: $regimg"
     echo -e "Private Image: $privimg"
     docker rmi -f $regimg
     docker rmi -f $privimg
     echo ----
  done < $imgfile
}
cd $olroot
skipCleaningLocalImages=${skipCleaningLocalImages:-true}
[ $skipCleaningLocalImages != true ] && cleanLocalImages

echo "DONE - Pushing Images !!!"
