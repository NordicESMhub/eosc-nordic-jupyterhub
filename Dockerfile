FROM quay.io/uninett/jupyterhub-singleuser:20191012-5691f5c

MAINTAINER Anne Fouilloux <annefou@geo.uio.no>

# Install packages
USER root
RUN apt-get update && apt-get install -y vim

# Install requirements for pangeo 
ADD pangeo_environment.yml pangeo_environment.yml

# Python packages
RUN conda env create -f pangeo_environment.yml && conda clean -yt
RUN ["/bin/bash" , "-c", ". /opt/conda/etc/profile.d/conda.sh && \
    conda activate pangeo && \
    python -m pip install ipykernel && \
    ipython kernel install --name pangeo && \
    python -m ipykernel install --name=pangeo && \
    jupyter labextension install @jupyterlab/hub-extension && \
    jupyter labextension install jupyterlab-datawidgets && \
    conda deactivate && \
    conda init bash"]

# Install requirements for eclimate 
ADD esmvaltool_environment.yml esmvaltool_environment.yml

# Python packages
RUN conda env create -f esmvaltool_environment.yml && conda clean -yt
RUN ["/bin/bash" , "-c", ". /opt/conda/etc/profile.d/conda.sh && \
    conda activate esmvaltool && \
    python -m pip install ipykernel && \
    ipython kernel install --name esmvaltool && \
    python -m ipykernel install --name=esmvaltool && \
    jupyter labextension install @jupyterlab/hub-extension && \
    jupyter labextension install jupyterlab-datawidgets && \
    conda deactivate && \
    conda init bash"]

# fix permission problems (hub is then failing)
RUN fix-permissions $HOME

# Install other packages
USER notebook
