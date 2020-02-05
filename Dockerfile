FROM python:3.7-slim
WORKDIR /workspace

RUN pip install bandit flake8 shellcheck-py yamllint

COPY docker-sast.sh /usr/local/bin/

ENTRYPOINT ["bash", "docker-sast.sh"]
