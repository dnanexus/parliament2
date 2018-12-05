#!/usr/bin/env bash

wget -q https://wiki.dnanexus.com/images/files/dx-toolkit-current-ubuntu-14.04-amd64.tar.gz
tar zxf dx-toolkit-current-ubuntu-14.04-amd64.tar.gz
source dx-toolkit/environment

sudo mkdir -p /home/dnanexus/in
sudo mkdir -p /home/dnanexus/out

dx login --token $DX_AUTH_TOKEN --noprojects
# Download small input BAM and index
dx download file-By3JP400k0B037Jpv1Jq856f -o /home/dnanexus/in/small_input.bam
dx download file-Bzp2vG80X3VQv24XgQx0Qy1J -o /home/dnanexus/small_input.bai
# Download reference FASTA and index
dx download file-B6ZY7VG2J35Vfvpkj8y0KZ01 -o /home/dnanexus/in/ref.fa.gz
dx download file-ByGVY4j04Y0YJ0yJpj0f8qPG -o /home/dnanexus/in/ref.fa.fai
docker run dnanexus/parliament2:$TAG -v /home/dnanexus/in:/home/dnanexus/in -v /home/dnanexus/out>:/home/dnanexus/out --bam small_input.bam --ref_genome ref.fa.gz --prefix breakdancer --breakdancer 