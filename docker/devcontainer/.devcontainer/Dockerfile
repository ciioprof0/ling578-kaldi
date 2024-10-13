# Start with the Kaldi base image
FROM kaldiasr/kaldi:latest

# Install additional required packages for SRILM
RUN apt-get update && apt-get install -y apt-utils flac gawk nano

# Install SRILM
RUN cd /opt/kaldi/tools && \
    ./install_srilm.sh "Wilbur Wilcat" "University of Arizona" "wilbur.wildcat@arizona.edu" "Tucson AZ 85721"

# Modify path.sh to source env.sh
RUN if ! grep -Fxq "source /opt/kaldi/tools/env.sh" /opt/kaldi/egs/very/path.sh; then \
        echo "source /opt/kaldi/tools/env.sh" >> /opt/kaldi/egs/very/path.sh; \
    fi

# Modify r2.sh to set nj to nproc-1
RUN sed -i 's/^nj=.*/nj=$(( $(nproc) - 1 ))/' /opt/kaldi/egs/very/r2.sh

# Copy your custom scripts into the container
COPY mhscripts/ /mhscripts/
RUN chmod +x /mhscripts/*.sh