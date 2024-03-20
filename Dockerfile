ARG NAUTOBOT_VERSION=2.1.5
ARG PYTHON_VERSION=3.11
FROM ghcr.io/nautobot/nautobot:${NAUTOBOT_VERSION}-py${PYTHON_VERSION}

COPY requirements.txt /tmp/

RUN pip install -r /tmp/requirements.txt

COPY ./configuration/nautobot_config.py /opt/nautobot/