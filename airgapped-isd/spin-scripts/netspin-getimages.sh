#!/bin/bash
# Purpose: Script to download Docker images from Internet Docker registry
#
# Notes: This script reads the Docker images from $srcroot/spin-ver.yml
# dependencies-and-overrides.yml and spinnaker helm chart 

sname=$(basename $BASH_SOURCE)
sdir=$(cd `dirname $BASH_SOURCE` && pwd)

source $sdir/spin-includes.sh

olroot=${olroot:-$PWD}
tarsdir=$olroot/offlinetars
srcroot=$olroot/offlinesrc
tmpdir=$olroot/offlinetmp
bomsroot=$srcroot/.boms
verfile=$bomsroot/bom/$spinver.yml
tmpverfile=$srcroot/spin-ver.yml
helmchartfile=https://helmcharts.opsmx.com/spinnaker-2.2.5.tgz
dependenciesoverridefile=$sdir/dependencies-and-overrides-pull.yml
images2pullfile=$olroot/netspin-images2pull.yml

ifCmdsAvailable yq docker svn gsutil curl wget
if [ $? -ne 0 ]; then
   echo "Make sure the required CLI tools are available and try again"
   exit 1
fi

assureDockerAccess
if [ $? -ne 0 ]; then #docker images command not working
   echo "Unable to run 'docker images' command. "
   echo "Quitting. Make sure 'docker' commands work in your Docker termiminal" 
   exit 2
fi

[ ! -d $tarsdir ] && mkdir -p $tarsdir
[ ! -d $srcroot ] && mkdir -p $srcroot; cd $srcroot
[ ! -d spin-images ] && mkdir spin-images


#Download Helm chart
skipChartDownload=${skipChartDownload:-false}
if [[ $skipChartDownload != true && ! -f $srcroot/$chartfile ]]; then
  echo -e "\n\n---> Fetching Spinnaker Helm chart - ${helmcharturl}"
  cd $srcroot; curl -LO ${helmcharturl}
  chartfile=$(basename $helmcharturl)
  echo "-----> Running 'helm template' on ${chartfile} to generate manifest (for getting image list)"
  # helm template <release> <chart> --output-dir <local-directory>
  helm template opsmx ${chartfile} --output-dir $srcroot/helmdir

  cp -f $srcroot/$chartfile $tarsdir
fi
  
# Download BOM version file. This is the base for driving the rest of the script
[ ! -s $tmpverfile ] && wget -O $tmpverfile https://storage.googleapis.com/halconfig/bom/$spinver.yml

echo "---> Identifying list of images to pull"
# 1. Helm template images, 2. Spinnaker BOM images, 3. Override images

getHelmImages() {
  echo "  --> Grep-ing manifests files for image list"
  grep -ir 'image:' $srcroot/helmdir | grep -v "[#;]" | sed "s/.*image: //" | tr -d \'\" | sort | uniq > $srcroot/helm-images.txt
  echo "  --> Grep completed. Image list is saved to $srcroot/helm-images.txt"
  echo "  --- Image list from $srcroot/helm-images.txt"
  cat $srcroot/helm-images.txt
  echo "  --- End of helm-images"

  # echo "  --> Getting Helm manifest Images list"
  # Get dependency images for services like Halyard, Minio and Redis
  # Previously this was pulled by reading spinnaker/values.yaml, spinnaker/charts/redis/values.yaml, and spinnaker/charts/minio/values.yaml 
  # and did not cover all possible images
  # Now, it is improved to grep all the images in the helm template output manifest files 
 
  # Images are written in the format
  # busybox
  # docker.io/devopsmx/ubi8-oes-operator-halyard:1.18.5
  # miniocli:v1.0

  echo "# Helm Images" > $srcroot/helm-images-tmp.yml

  while IFS= read -r line; do
     # echo "$line"
     #Sample $lines
     #busybox #Assumes default registry - docker.io, and default tag - latest
     #docker.io/devopsmx/ubi8-oes-gate #Assumes default tag - latest
     #docker.io/devopsmx/ubi8-oes-gate:version-1.14.0

     # echo quay.io/opsmxpublic/ubi8-oes-platform:v4.0.3.1 | sed -r -e "s|(.*/)?([^:]+)(:(.+))?$|\4|"
     # \1 - Registry [quay.io/opsmxpublic/]
     # \2 - Repository [ubi8-oes-gate]
     # \3 - Tag with colon prefix [:version-1.14.0]
     # \4 - Tag without colon prefix [version-1.14.0]
     # sed -r -e "s|((.*/)?([^:]+)(:(.+))?)$|\3: \1|" helm-images-tmp.yml >> $images2pullfile

     registryimg=$line
     imgnametag=$(basename $registryimg)
     imgname=$(echo $imgnametag | awk -F ':' '{print $1}')
     imgtag=$(echo $imgnametag | awk -F ':' '{print $2}')
     echo "$imgname: $registryimg" >> $srcroot/helm-images-tmp.yml
     #echo ----
  done < $srcroot/helm-images.txt
}

skipHelmImages=${skipHelmImages:-false}
[ $skipHelmImages != true ] && getHelmImages

#dcr=$(yq r $tmpverfile artifactSources.dockerRegistry)
dcr=$(yq eval '.artifactSources.dockerRegistry' $tmpverfile)
getBomImages() {
  # Reading image list from a copy of ~/.hal/.boms/bom/<x.y.z>.yml #Where x.y.z is something like 1.28.6 which is Spinnaker version
  echo "  --> Getting BOM Images list"
  #declare -a services=$(yq eval '.services' $tmpverfile  | egrep -v ' .*|monit' | sed 's/:$//')
  #Remove services starting with a space or text 'defaultArtifact' which has version null item
  declare -a services=$(yq eval '.services' $tmpverfile  | egrep -v ' .*|defaultArtifact' | sed 's/:$//')
  #declare -a services=$(yq eval '.services' $tmpverfile  | egrep -v ' .*' | sed 's/:$//')
  #yq eval '.services' spin-ver.yml | egrep -v ' .*|defaultArtifact' | sed 's/:$//'

  echo "# Spinnaker BOM Images" > $srcroot/spinnaker-images-tmp.yml

  pass=0
  for x in ${services[@]}; do
    pass=$((pass+1))
    #echo "Pass $pass"
    #echo "x|=> $x"
    #Remove the surrounding quotes from the service-name
    xname=$(echo $x | sed 's/^"\|"$//g')
    #xver=$(yq r $tmpverfile services.$x.version) #Value is yielded without quotes
    xver=$(yq eval ".services.$x.version" $tmpverfile) #Value is yielded without quotes
    if [[ $xver == 'null' ]]; then continue; fi #If items like .services.defaultArtifact.version is null, dont print it
    echo "BOM |$xname|=> $dcr/$xname:$xver"
    echo "$xname: $dcr/$xname:$xver" >> $srcroot/spinnaker-images-tmp.yml #A temp file to see the list of Spinnaker only images
  done
}
skipBomImages=${skipBomImages:-false}
[ $skipBomImages != true ] && getBomImages

getOverrideImages() {
  # Get sub-items of dependencies, spinnaker, & opsmx and delete blank & comment lines
  # yq eval ".dependencies" $dependenciesoverridefile | sed -e '/^\s*$/d' -e '/^\s*#/d' >> $images2pullfile
  # yq eval ".spinnaker" $dependenciesoverridefile | sed -e '/^\s*$/d' -e '/^\s*#/d' >> $images2pullfile
  # yq eval ".opsmx" $dependenciesoverridefile | sed -e '/^\s*$/d' -e '/^\s*#/d' >> $images2pullfile

  # Sample line
  # clouddriver-rw: quay.io/opsmxpublic/ubi8-spin-clouddriver:7.2.2
  # [or]
  # quay.io/opsmxpublic/ubi8-spin-clouddriver:7.2.2

  echo "# Images from $dependenciesoverridefile are formatted into $srcroot/imageoverrides-tmp.yml"
  echo "# Dependencies and Override images " > $srcroot/imageoverrides-tmp.yml

  #dependenciesoverridefile file format
  #dependencies: [or] spinnaker: [or] opsmx:
  #  quay.io/opsmxpublic/ubi8-oes-autopilot:v3.8.3
  # [OR]
  #Lines without headings and no leading spaces
  # quay.io/opsmxpublic/ubi8-spin-halyard:opsmx-1.40.0

  #From $dependenciesoverridefile, delete blank lines, commented lines and key-only lines (like dependencies: spinnaker: opsmx:)
  sed -e '/^\s*$/d' -e '/^\s*#/d' -e '/.*:\s*$/d' -e 's/^\s*//' $dependenciesoverridefile >> $srcroot/imageoverrides-tmp.yml
  # Assumption 2nd line is not comment and a valid docker registry
  # You should either put <key: registry> format or just <registry> format in the file
  # 2nd line is processed. sed after pipe | removes leading and trailing spaces
  regline=$(sed '2q;d' $srcroot/imageoverrides-tmp.yml | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )

  if ! [[ $regline =~ .*:[[:space:]] ]]; then #If not dockername: registry, then create dockername: registry format
     # echo quay.io/opsmxpublic/ubi8-oes-platform:v4.0.3.1 | sed -r -e "s|(.*/)?([^:]+)(:(.+))?$|\4|"
     # \1 - Full registry with reposity:tag
     # \2 - Registry [quay.io/opsmxpublic/]
     # \3 - Repository [ubi8-oes-gate]
     # \4 - Tag with colon prefix [:version-1.14.0]
     # \5 - Tag without colon prefix [version-1.14.0]
     sed -i -r -e "s|((.*/)?([^:]+)(:(.+))?)$|\3: \1|" $srcroot/imageoverrides-tmp.yml
  fi
}
skipOverrideImages=${skipOverrideImages:-false}
[ $skipOverrideImages != true ] && getOverrideImages

echo "--- Images to pull are here: $images2pullfile"
cat /dev/null > $images2pullfile
echo "# Note: This is auto-generated file [images2pull]. Do not edit manually" > $images2pullfile

if [ $skipHelmImages != true ]; then
  echo " " >> $images2pullfile
  cat $srcroot/helm-images-tmp.yml >> $images2pullfile
fi

if [ $skipBomImages != true ]; then
  echo " " >> $images2pullfile
  cat $srcroot/spinnaker-images-tmp.yml >> $images2pullfile
fi

if [ $skipOverrideImages != true ]; then
  echo " " >> $images2pullfile
  cat $srcroot/imageoverrides-tmp.yml >> $images2pullfile
fi

cat $images2pullfile
echo ---

echo "-----> Pulling Docker images for offline Spinnaker"

pullImages() {
  # Create a temp file from $images2pullfile without comment, blank lines

  #From $images2pullfile, delete blank lines, commented lines 
  sed -e '/^\s*$/d' -e '/^\s*#/d' -e 's/^\s*//' $images2pullfile > $images2pullfile.tmp

  while IFS= read -r line; do
     echo "$line"
     #Sample $line
     #gate: docker.io/devopsmx/ubi8-oes-gate:version-1.14.0
     msvc=$(echo $line | awk -F ": " '{print $1}')
     registryimg=$(echo $line | awk -F ": " '{print $2}')
     imgnametag=$(basename $registryimg)
     imgname=$(echo $imgnametag | awk -F ':' '{print $1}')
     imgtag=$(echo $imgnametag | awk -F ':' '{print $2}')
     #echo -n "$registryimg \n $imgnametag \n $imgname \n $imgtag"
     skipImagesPull=${skipImagesPull:-false}
     if [ $skipImagesPull != true ]; then
       echo "Pulling - $registryimg"
       docker pull $registryimg
     fi
     skipImagesSave=${skipImagesSave:-false}
     if [ $skipImagesSave != true ]; then
       if [ -z $imgtag ]; then
	  tarname=$imgname
       else
	  tarname=${imgname}_${imgtag}
       fi
       echo "Saving - $registryimg as spin-images/$tarname.tar"
       docker save $registryimg -o spin-images/$tarname.tar
     fi
     echo ----
  done < $images2pullfile.tmp
}
skipImagesPull=${skipImagesPull:-false}
skipImagesSave=${skipImagesSave:-false}
#If both conditions are true, then donot call the function. If atleast one condition is false, call the function
#[ $skipImagesPull != true || $skipImagesSave != true ] && pullImages
[[ $skipImagesPull == true && $skipImagesSave == true ]] || pullImages


tarImages() {
  cd $srcroot
  echo "Creating $srcroot/spin-images.tar.gz"
  chown -R $(id -u):$(id -g) spin-images
  set -x
  tar -czvf spin-images.tar.gz spin-images
  set +x
  [ -f $srcroot/spin-images.tar.gz ] && mv $srcroot/spin-images.tar.gz $tarsdir/
  [ $? -eq 0 ] && echo "Moved $srcroot/spin-images.tar.gz to $tarsdir/spin-images.tar.gz"
}
cd $olroot
skipImagesTar=${skipImagesTar:-false}
[ $skipImagesTar != true ] && tarImages

echo "DONE - Docker Image Pull !!!"
