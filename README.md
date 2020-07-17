# Container SAST

This container runs a SAST scan with support for Google Cloud.

## Installation
* Make sure Docker is properly installed on your system.
* Clone the repository.
## Usage
**NOTE: Trufflehog is called with `max_depth=1`. Manually run it to check entire history.**  
Locally with only Docker: 

```shell script
foo@bar:cloudbuilder-sast$ docker build . -t <image_name>
docker run -v <directory to run from>:/tmp <image_name> --target /tmp --no-jsonlint
```
Note: target cannot be "/" since this would cause target to be the only thing visible in the container  

Including this container in a Cloudbuilder script:
```yaml
- name: "eu.gcr.io/${PROJECT_ID}/cloudbuilder-sast"
args: ["arg1", "val1", "arg2", "arg3"]
```

## Configuration
### Arguments
Cloudbuilder-sast takes one required and two optional arguments:  
```
Required:  
    --target [target]                                   Path to target to run on
Optional:
    --help                                              Print usage and exit
    --context [pre-commit | post-commit | cloudbuild]   What context to run in
```
### Additional configuration
Any configuration files for either the cloudbuilder-sast or any of the tools can be placed in a "sast-config" folder.
The contents of the folder `/sast-config` will be copied to the top-level of the directory.
Any config files outside of will only be found during cloudbuild if the tool allows it.  

#### SAST scan checks for the following files in /sast-config:
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
### Yamllint configuration
Yamllint is preconfigured with 
```yaml
---

extends: default

ignore: |
  .node_modules,

rules: 
  line-length:
    max: 120
```
Since yamllint does not support both config_data and config_file, adding a config file overwrites this predefined 
configuration. If you wish to use this configuration, make sure to add it to your new config file.

### Bandit configuration
Bandit is preconfigured with 
```yaml
[bandit]
exclude: /.node_modules 
skips: B105
```
Since Bandit does not support both command line arguments and a config file, adding a config file overwrites this predefined 
configuration. If you wish to use this configuration, make sure to add it to your new config file.


## Excluding false positives
**NOTE: Only exclude findings if you are absolutely certain it is a false positive.**  
**If it is not a false positive, fix the finding instead.**
 
If cloudbuilder sast finds any false positives, follow these steps to fix them.  

*Note: the custom Json linter does not have any configuration options.*
### - If the file should not be scanned
* **Shellcheck:** Shellcheck does not have support for excluding files. It is however possible to add a comment just
 below the shebang containing `# shellcheck disable=SCXXXX` where XXXX is the check you want to disable. Multiple checks
 can be disabled by comma separation (e.g. SC1234,SC1235,SC1236).
* **Yamllint:** Yamllint has no support for file exclusions.
* **Trufflehog:** add the line `--exclude_paths trufflehog_exclude_file` to the Trufflehog config file. Add one regex 
exclude path per line to `trufflehog_exclude_file`.
* **Bandit:** add an `exclude` section to the Bandit config file.
 [docs](https://bandit.readthedocs.io/en/latest/config.html)
* **Flake8:** add an `exclude` section to the Flake8 config file.
 [docs](https://flake8.pycqa.org/en/latest/user/configuration.html)
* **Eslint:** see the
 [Eslint docs](https://eslint.org/docs/user-guide/configuring#configuration-based-on-glob-patterns) for more 
 infomation.

### - If the rule does not apply to the project
It is possible to disable rules per project in the config files:
* **Shellcheck:** add a shellcheck config file containing the -e flag + whatever codes to exclude e.g. `-e SC1000,SC2000`
* **Yamllint:** add a `rules` section to the Yamllint config file. [docs](https://yamllint.readthedocs.io/en/stable/configuration.html)
* **Trufflehog:** it is not possible to disable a rule for the entire project. It is however possible to ignore the 
default regexes and specify a custom list of regexes. This is done by adding `--rules trufflehog_rules.json` to the
Trufflehog config file. If no `--rules trufflehog_rules.json` is added, a default DAT rule list is applied.
* **Bandit:** add a `skips` section to the Bandit config file. [docs](https://bandit.readthedocs.io/en/latest/config.html)
* **Flake8:** add an `ignore` section to the Flake8 config file. [docs](https://flake8.pycqa.org/en/latest/user/configuration.html)
* **Eslint:** see the
 [Eslint docs](https://eslint.org/docs/user-guide/configuring#configuration-based-on-glob-patterns) for more 
 infomation.

### - If the just the line is a false positive
It is possible to exclude single lines for some tools:
* **Shellcheck:** add a line above containing `# shellcheck disable=SCXXXX` where XXXX is the check you want to disable.
 Multiple checks can be disabled by comma separation (e.g. `SC1234,SC1235,SC1236`).
* **Yamllint:** yamllint does not allow single line exclusions
* **Trufflehog:** add a comment after the line with `no_trufflehog` or use --entropy-exclude-regex.
* **Bandit:** add a `#nosec` comment after the line
* **Flake8:** add a `# noqa: A000` comment after the line where A000 is the check you want to disable. Multiple checks can 
be disabled by comma separation (e.g. `E123,W123,F123`).
* **Eslint:** Eslint has more advanced inline disables, see the
 [Eslint docs](https://eslint.org/docs/2.13.1/user-guide/configuring#disabling-rules-with-inline-comments) for more 
 infomation.
