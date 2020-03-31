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

Run ```--help``` for more information on arguments.

Config files may be added to a sast-config folder in a target directory. SAST scan checks for the following files in
 /sast-config:

shellcheck:
`.shellcheck`  
yamllint:
`.yamllint` `yamllint.yaml` `yamllint.yml`  
jsonlint:
none  
trufflehog:
`.trufflehog`  
bandit:
`.bandit`  
flake8:
`setup.cfg` `tox.ini` `.flake8`  
eslint:
`eslintrc.json` (Note that it is isn't hidden)

For configuration options see the documentation of the respective tool.