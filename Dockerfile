FROM python:3.7-slim
WORKDIR /workspace

RUN pip install bandit flake8 shellcheck-py yamllint
RUN apt update && apt install -y curl git && curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt install -y nodejs
RUN npm install -g typescript && npm install -g tslint && npm install -g zaach/jsonlint

COPY docker-sast.sh /usr/local/bin/

ENTRYPOINT ["bash", "docker-sast.sh"]
