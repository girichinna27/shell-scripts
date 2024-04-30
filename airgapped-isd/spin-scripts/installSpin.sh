#cp -v priv-docker-reg.yml airgapped-spin/
#cd airgapped-spin;
#export http_proxy=
#export https_proxy=
#helm --debug install --set halyard.spinnakerVersion=local:1.18.5,halyard.image.tag=1.29.0, \
#  --set halyard.additionalScripts.enabled=true,halyard.additionalScripts.configMapName=cm-spinnaker-boms, \
#  --set halyard.additionalScripts.configMapKey=callCopyBoms.sh,redis.image.pullPolicy=IfNotPresent \
#  --set minio.image.repository=10.168.3.10:8082/minio,halyard.image.repository=docker.artifactory.booking.com/projects/mmobarak/halyard \
#  --set redis.image.registry=10.168.3.10:8082,redis.image.repository=redis \
#  --set gcs.enabled=false -f values.yaml -f priv-docker-reg.yml spin spinnaker-1.23.1.tgz -n mmobarak-mmobarak-2c98ad68 \
#  --timeout 20m0s | tee helminstall.log


#cp -v priv-docker-reg.yml offlinetars/
#cd offlinetars
#export http_proxy=
#export https_proxy=

export spinver=${spinver:-1.20.3}
export rel=${rel:-spin}

helm --debug install --set halyard.spinnakerVersion=local:$spinver \
  --set halyard.image.repository=devopsmx/ubi8-oes-operator-halyard \
  --set halyard.image.tag=1.18.5 \
  --set minio.image.tag=RELEASE.2019-09-18T21-55-05Z \
  --set redis.image.pullPolicy=IfNotPresent \
  --set redis.image.repository=bitnami/redis \
  --set redis.image.tag=5.0.7-debian-10-r0 \
  --set gcs.enable=false \
  -f values.yaml \
  $rel offlinetars/spinnaker \
  -n $knamespace --timeout 20m0s | tee install.log
#  -n mmobarak-mmobarak-2c98ad68 --timeout 20m0s \
#  spnrel spinnaker-1.23.1.tgz  -n mmobarak-mmobarak-2c98ad68 --timeout 20m0s >  helmTemplate.yaml

# --set minio.image.repository=docker.artifactory.booking.com/projects/panh/ubi8-oes-minio \
#  --set minio.image.tag=RELEASE.2019-09-18T21-55-05Z \
#  --set redis.image.registry=docker.artifactory.booking.com/projects/panh \
#  --set redis.image.repository=ubi8-oes-redis \
#  --set redis.image.tag=4.0.11-debian-9 \
#  --set redis.image.pullPolicy=IfNotPresent \
#  --set halyard.additionalScripts.enabled=true \
#  --set halyard.additionalScripts.configMapName=cm-spinnaker-boms \
#  --set halyard.additionalScripts.configMapKey=callCopyBoms.sh \
#  --set gcs.enable=false \

