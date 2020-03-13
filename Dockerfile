FROM python:3.7-slim
WORKDIR /workspace

RUN pip install bandit flake8 shellcheck-py yamllint

RUN apt update \
&& apt install -y curl git \
&& curl -sL https://deb.nodesource.com/setup_10.x | bash - \
&& apt install -y nodejs \
&& git clone --single-branch --branch develop https://github.com/vwt-digital/truffleHog.git
RUN pip install -r truffleHog/requirements.txt

RUN npm install -g typescript \
&& npm install -g tslint

ARG CACHEBUST=1

COPY test.py test.py
COPY docker-sast.sh /usr/local/bin/
COPY jsonlint.py /usr/local/bin
ADD tests tests

RUN ["python3", "test.py"]

ARG CACHEBUST=0


ENTRYPOINT ["bash", "docker-sast.sh"]
