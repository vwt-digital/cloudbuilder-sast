# Container SAST

This container runs a SAST scan with support for Google Cloud.

## Usage
Locally with only Docker: 
```shell script
foo@bar:cloudbuilder-sast$ docker build . -t <image_name>
docker run -v <directory to run from>:/tmp <image_name> --target /tmp --no-jsonlint
```
(Note: target cannot be "/" since this would cause target to be the only thing visible in the container)  

Including this container in a Cloudbuild config file:
```yaml
- name: "eu.gcr.io/${PROJECT_ID}/cloudbuilder-sast"
args: ["arg1", "val1", "arg2", "arg3"]
```

Run ```--help``` for more information on arguments.

The contents of the folder `/sast-config` will be copied into the container for configuration.
Any config files outside of this folder will not be found.  

SAST scan checks for the following files in /sast-config:

   SAST:
   `.sast` `.sast-config`  
   shellcheck:
   `.shellcheck`  
   yamllint:
   `.yamllint` `yamllint.yaml` `yamllint.yml`  
   custom json linter:
   none  
   trufflehog:
   `.trufflehog`  
   bandit:
   `.bandit`  
   flake8:
   `setup.cfg` `tox.ini` `.flake8`  
   eslint:
   `eslintrc.json` (Note that it isn't hidden)

For configuration options see the documentation of the respective tool.
