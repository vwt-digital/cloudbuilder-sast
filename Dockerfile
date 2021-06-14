FROM python:3.7-slim
WORKDIR /workspace

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt --use-deprecated=legacy-resolver

RUN apt update \
    && apt install -y curl git \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt install -y nodejs \
    && git clone --single-branch --branch develop https://github.com/vwt-digital/truffleHog.git
RUN pip install -r truffleHog/requirements.txt \
    && cp truffleHog/truffleHog/truffleHog.py /usr/local/bin \
    && chmod 755 /usr/local/bin/truffleHog.py

RUN npm install -g typescript \
    && npm install -g eslint

ARG CACHEBUST=1

COPY test.py test.py
COPY docker-sast.sh /usr/local/bin/
COPY jsonlint.py /usr/local/bin
COPY eslintrc.json /usr/local/etc
COPY thrules.json /usr/local/etc
COPY thexclude.txt /usr/local/etc
COPY .trufflehog /usr/local/etc

ADD tests tests
RUN mkdir tests/node_modules \
    && npm install --prefix tests \
    eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser typescript \
    && cp -r tests/node_modules tests/positive/eslint_positive \
    && cp -r tests/node_modules tests/negative/eslint_negative

RUN cd tests/negative/trufflehog_highentropy \
    && git init . \
    && git add -A . \
    && git config --global user.email "test@example.com" \
    && git config --global user.name "test" \
    && git commit -a -m "Neg" \
    && cd ../../positive/trufflehog_ignoreline \
    && git init . \
    && git add -A . \
    && git commit -a -m "Pos" \
    && cd ../../../ \
    && python3 test.py

# cleanup /workspace
RUN rm -fr tests truffleHog test.py

ARG CACHEBUST=0

ENTRYPOINT ["bash", "docker-sast.sh"]
