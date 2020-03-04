# Container SAST

This container runs a SAST scan with support for Google Cloud.

## Usage
Locally with only Docker: 
```shell script
foo@bar:cloudbuilder-sast$ docker build . -t <image_name>
docker run -v <directory to run from>:/tmp <image_name> --target /tmp --trufflehog --cleanup /tmp --no-jsonlint
```
Including this container in a Cloudbuild config file:
```yaml
- name: "eu.gcr.io/${PROJECT_ID}/cloudbuilder-sast"
args: ["arg1", "val1", "arg2", "arg3"]
```

Run ```--help``` for more information on arguments
