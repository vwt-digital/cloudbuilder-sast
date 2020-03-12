# Container SAST

This container runs a SAST scan with support for Google Cloud.

## Usage
Locally with only Docker: 
```shell script
foo@bar:cloudbuilder-sast$ docker build . -t <image_name>
docker run -v <directory to run from>:/tmp <image_name> --target /tmp --no-jsonlint
```
Including this container in a Cloudbuild config file:
```yaml
- name: "eu.gcr.io/${PROJECT_ID}/cloudbuilder-sast"
args: ["arg1", "val1", "arg2", "arg3"]
```

Run ```--help``` for more information on arguments

A configuration file may add extra arguments. The arguments will be added as words in order.  
For example this configuration file is valid:
```shell script
# .sast-config
--no-shellscript --no-yamllint
--target . --type
bandit
```