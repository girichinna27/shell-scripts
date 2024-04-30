olroot=$PWD
cd /tmp; sudo rm -rvf pv-spin; 
mkdir -p pv-spin/halyard pv-spin/minio pv-spin/redis;
chmod -R 777 pv-spin/

cd $olroot; kubectl apply -f spin-manualPV.yaml
