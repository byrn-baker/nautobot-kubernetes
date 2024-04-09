ARG NAUTOBOT_VERSION=stable
ARG PYTHON_VERSION=3.11
FROM ghcr.io/nautobot/nautobot:${NAUTOBOT_VERSION}-py${PYTHON_VERSION}

COPY requirements.txt /tmp/

RUN pip install -r /tmp/requirements.txt

COPY ./config/nautobot_config.py /opt/nautobot/

ARG GITLAB_USERNAME
ENV GITLAB_USERNAME=${GITLAB_USERNAME}

ARG GITLAB_TOKEN
ENV GITLAB_TOKEN=${GITLAB_TOKEN}