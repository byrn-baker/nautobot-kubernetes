ARG NAUTOBOT_VERSION=stable
ARG PYTHON_VERSION=3.11
FROM ghcr.io/nautobot/nautobot:${NAUTOBOT_VERSION}-py${PYTHON_VERSION}

COPY requirements.txt /tmp/

RUN pip install -r /tmp/requirements.txt

COPY ./config/nautobot_config.py /opt/nautobot/
