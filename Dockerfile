FROM jupyter/scipy-notebook:ubuntu-18.04 as miniconda

USER root

RUN conda config --set channel_priority strict && \
    conda install --quiet --yes --update-all -c conda-forge \
    'nbconvert' \
    'tqdm' \
    'yapf==0.29*' \
    'rise==5.6.*' \
    'nbdime==2.*' \
    'jupyterhub==1.1.0' \
    'jupyterlab==2.1.*' \
    'jupyter_contrib_nbextensions==0.5*' \
    'nbgitpuller=0.8' \
    'distributed' \
    'dask-kubernetes' \
    'dask-gateway' \
    'dask-labextension' \
    'tornado' \
    'python-graphviz=0.13' \
    'jupyter-server-proxy==1.4*' && \
    jupyter labextension install \
    '@jupyterlab/github' \
    'nbdime-jupyterlab' \
    '@jupyterlab/toc' \
    '@jupyterlab/hub-extension' && \
    pip install ipyparallel==6.2.* jupyterlab-github escapism && \
    git clone https://github.com/paalka/nbresuse /tmp/nbresuse && pip install /tmp/nbresuse/ && \
    jupyter serverextension enable --py nbresuse --sys-prefix && \
    jupyter serverextension enable jupyter_server_proxy --sys-prefix && \
    jupyter nbextension install --py nbresuse --sys-prefix && \
    jupyter nbextension enable --py nbresuse --sys-prefix

ADD pangeo_environment.yml pangeo_environment.yml
RUN conda update -n base conda && conda env update --file pangeo_environment.yml && \
    jupyter labextension install @pyviz/jupyterlab_pyviz \
                                 jupyter-leaflet  \
                                 jupyter-matplotlib

# Install requirements for eclimate 
ADD esmvaltool_environment.yml esmvaltool_environment.yml

# Python packages
RUN conda env create -f esmvaltool_environment.yml && conda clean -yt

RUN ["/bin/bash" , "-c", ". /opt/conda/etc/profile.d/conda.sh && \
    conda activate esmvaltool && \
    mkdir -p /opt/conda/envs/esmvaltool/src && \
    wget https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz && \
    tar zxvf julia-1.5.3-linux-x86_64.tar.gz --directory /opt/conda/envs/esmvaltool/src && \
    ln -s /opt/conda/envs/esmvaltool/src/julia-1.5.3/bin/julia /opt/conda/envs/esmvaltool/bin/julia  && \
    conda install -c esmvalgroup -c conda-forge esmvaltool==2.1.1 && \
    conda deactivate"]

# Install requirements for eclimate 
ADD cmor_environment.yml cmor_environment.yml

# Python packages
RUN conda env create -f cmor_environment.yml && conda clean -yt

ENV CMOR_ROOT=/opt/conda/pkgs/noresm2cmor-3.0.1
RUN ["/bin/bash" , "-c", ". /opt/conda/etc/profile.d/conda.sh && \
    conda activate cmor && \
    git clone https://github.com/EC-Earth/ece2cmor3.git && \
    cd ece2cmor3 && \
    git submodule update --init --recursive && \
    python setup.py install && \
    cd .. && rm -rf ece2cmor3 && \
    cd /opt/conda/pkgs && \
    wget https://github.com/NordicESMhub/noresm2cmor/archive/v3.0.1.tar.gz --no-check-certificate && \
    tar zxf v3.0.1.tar.gz && \
    cd noresm2cmor-3.0.1/build && \
    make -f Makefile_cmor3.jh_gnu && \
    make -f Makefile_cmor3mpi.jh_gnu && \
    rm -rf ../v3.0.1.tar.gz && \
    rm -rf *.o *.mod && \
    cp ../bin/noresm2cmor3  ../bin/noresm2cmor3_mpi /opt/conda/envs/cmor/bin/ && \
    conda deactivate"]

RUN /opt/conda/bin/ipython kernel install --name esmvaltool && \
    /opt/conda/bin/python -m ipykernel install --name=esmvaltool \
                          --display-name "ESMValTool" 

FROM jupyter/scipy-notebook:ubuntu-18.04

LABEL maintainer Anne Fouilloux <annefou@geo.uio.no>
USER root

# Setup ENV for Appstore to be picked up
ENV APP_UID=999 \
	APP_GID=999 \
	PKG_JUPYTER_NOTEBOOK_VERSION=5.7.x
RUN groupadd -g "$APP_GID" notebook && \
    useradd -m -s /bin/bash -N -u "$APP_UID" -g notebook notebook && \
    usermod -G users notebook && chmod go+rwx -R "$CONDA_DIR/bin"
COPY --chown=notebook:notebook --from=miniconda $CONDA_DIR $CONDA_DIR

ADD pangeo64x64.png /opt/conda/share/jupyter/kernels/python3/logo-64x64.png 
RUN chmod 664 /opt/conda/share/jupyter/kernels/python3/logo-64x64.png
ADD pangeo32x32.png /opt/conda/share/jupyter/kernels/python3/logo-32x32.png 
RUN chmod 664 /opt/conda/share/jupyter/kernels/python3/logo-32x32.png

# hadolint ignore=DL3002
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends gnupg2 curl && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    rm -rf /var/lib/apt/lists/*


# Refer here for versions https://gitlab.com/nvidia/cuda/blob/ubuntu16.04/10.0/base/Dockerfile,
# note that this uses Ubuntu 16.04.
#
# https://www.tensorflow.org/install/gpu
#  and
# https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/gpu-jupyter.Dockerfile
# might also be useful for CUDA packages
#
ENV PKG_CUDA_VERSION=10.0.130 \
    NCCL_VERSION=2.4.2 \
    PKG_CUDNN_VERSION=7.5.0.56

RUN apt-get update && apt-get install -y --no-install-recommends \
        "cuda-cudart-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-cublas-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-cublas-dev-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-cudart-dev-10-0=$PKG_CUDA_VERSION-1" \
        "libcudnn7=$PKG_CUDNN_VERSION-1+cuda10.0" \
        "libcudnn7-dev=$PKG_CUDNN_VERSION-1+cuda10.0" \
        "cuda-libraries-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-libraries-dev-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-nvml-dev-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-minimal-build-10-0=$PKG_CUDA_VERSION-1" \
        "cuda-command-line-tools-10-0=$PKG_CUDA_VERSION-1" \
        "libnccl2=$NCCL_VERSION-1+cuda10.0" \
        "libnccl-dev=$NCCL_VERSION-1+cuda10.0" \
        "cuda-compat-10-0=410.48-1" \
        "openmpi-bin=2.1.1-8" && \
    ln -s cuda-10.0 /usr/local/cuda && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/cuda/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
    ln -s /usr/local/cuda/include/* /usr/include/

RUN apt-get update && apt-get install -y --no-install-recommends \
	openssh-client=1:7.6p1-4ubuntu0.3 \
	less=487-0.1 \
	net-tools=1.60+git20161116.90da8a0-1ubuntu1 \
	man-db=2.8.3-2ubuntu0.1 \
	iputils-ping=3:20161105-1ubuntu3 \
	screen=4.6.2-1ubuntu1.1 \
	tmux=2.6-3ubuntu0.2 \
	graphviz=2.40.1-2 \
	cmake \
	rsync=3.1.2-2.1ubuntu1.1 \
	p7zip-full=16.02+dfsg-6 \
	tzdata \
	vim=2:8.0.1453-1ubuntu1.4 \
	unrar=1:5.5.8-1 \
	ca-certificates=20210119~18.04.1 \
    sudo=1.8.21p2-3ubuntu1.4 \
    inkscape=0.92.3-1 \
    "openmpi-bin=2.1.1-8" && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime

RUN mkdir -p /etc/profile.d && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

    
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH} \
    NVIDIA_VISIBLE_DEVICES="" \
    NVIDIA_DRIVER_CAPABILITIES=all \
    TZ="Europe/Oslo"

ENV HOME=/home/notebook \
    XDG_CACHE_HOME=/home/notebook/.cache/
COPY normalize-username.py start-notebook.sh /usr/local/bin/
COPY --chown=notebook:notebook .jupyter/ /opt/.jupyter/
RUN mkdir -p /home/notebook/.ipython/profile_default/security/ && chmod go+rwx -R "$CONDA_DIR/bin" && chown notebook:notebook -R "$CONDA_DIR/bin" "$HOME" && \
    mkdir -p "$CONDA_DIR/.condatmp" && chmod go+rwx "$CONDA_DIR/.condatmp" && chown notebook:notebook "$CONDA_DIR"

# hadolint ignore=DL3002
RUN chmod go+w -R "$HOME" && chmod o+w /home && rm -r /home/notebook

USER notebook
WORKDIR $HOME
CMD ["/usr/local/bin/start-notebook.sh"]
