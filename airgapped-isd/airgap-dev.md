# Airgapped ISD Scripts - TechNotes

Package for airgapped installation is generated in a Internet connected machine (x86_AMD) through Docker container. Then package is shipped to Customer's airgapped env. The package is extracted and used for ISD/Spinnaker installation on a airgapped K8s cluster.

Scripts here are used to generate Offline/Air-gapped Spinnaker package bundle. This instruction is meant if you want to modify the packaging scripts and build a new Docker airgapped-isd image.


## Modifying Airgapped Packaging Scripts

During script development, clone this git repo and cd to repo directory, then run:  
`docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/tmp/airgapped-isd -v $PWD:/tmp/hostdir -w /tmp/airgapped-isd airgapped-isd:latest bash`

Once you are in container and your working directory is /tmp/airgapped-isd, you can modify the scripts, and test them.

Upon completing scripts edit, you can open a parallel terminal or exit the container to commit the changes
```
git status
git diff <file>
git add <file>
git commit -m <comment>
git push
```


## Creating Base Image for Air-gapped Spinnaker Package Building

After modifying the packaging scripts, to make them as part of the Docker image, you need to build a new image

To build docker image, run command: 
```
docker build --force-rm -t airgapped-isd:<ver> .
docker build --force-rm -t airgapped-isd:latest . 
```

To run docker container from the image, run command:  
`docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock airgapped-isd:<ver> bash`

During script development, clone this git repo and cd to repo directory, then run:  
`docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/tmp/airgapped-isd -v $PWD:/tmp/hostdir -w /tmp/airgapped-isd airgapped-isd:latest bash`


