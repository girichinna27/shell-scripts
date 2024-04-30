FROM ubuntu:22.04

# Create image with the below command
# docker build --force-rm -t <tag> .
# Run the container with the below command
# docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock <tag> bash
# During Docker image Development testing. In container, test scripts from /tmp/gitspin
# docker run -it --rm -v $PWD:/tmp/gitspin -v /var/run/docker.sock:/var/run/docker.sock <tag> bash

# LABEL about the custom image
LABEL maintainer="sagayaraj.d@opsmx.io"
LABEL version="v1.0"
LABEL description="Base image to generate airgapped installation bundle"

WORKDIR ./

# Default shell for the RUN instruction is ["/bin/sh", "-c"], switch to bash
SHELL ["/bin/bash", "-c"] 

# COPY [^n]*    # All files that don't start with 'n'
# COPY n[^o]*   # All files that start with 'n', but not 'no'
# COPY no[^d]*  # All files that start with 'no', but not 'nod'

#COPY insUtis.sh /opt/scripts/
COPY spin-scripts/ /opt/spin-scripts/
# Docker creates layer for each RUN commands, a script is doing all the installation under a single layer
RUN bash /opt/spin-scripts/installUtils-dkr.sh

# Expose Port for the Application 
#EXPOSE 80 443

CMD ["bash"]
