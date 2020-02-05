#! /usr/bin/env bash

# usage docker run -v <directory to run from>:"$(pwd) sast-scan-python-test --target "$(pwd)"

# keep exit values after pipe: this makes it so the build step will correctly exit with error if one of the tests fails
set -o pipefail

if [[ "$#" -eq 0 ]]; then
  printf "No arguments given \n"
  exit 0
fi

out_dir=$("pwd")/sast_output/

while :
do
    case "$1" in
      --help)
        echo "Usage:"
        echo "required arguments:"
        echo
        echo "--type: what sast test to run (options: frontend, backend)"
        echo "--target: the target to run on"
        echo
        echo "optional arguments:"
        echo
        echo "frontend:"
        echo "--help: print usage and exit"
        echo "--out_dir: location for output files (Default: \$pwd/sast_output)"
        echo "--no_bandit: disable bandit scan"
        echo "--no_shellcheck: disable shellcheck linter"
        echo "--no_flake8: disable flake8 scan"
        echo "--no_yamllint: disable yamllint linter"
        echo
        echo "backend:"
        #TODO: backend commands
        exit 0
        ;;
      --target)
        target=$2
        shift 2
        ;;
      --out_dir)
        out_dir=$2
        shift 2
        ;;
      --no-bandit)
        no_bandit=true
        shift 1
        ;;
      --no-shellcheck)
        no_shellcheck=true
        shift 1
        ;;
      --no-flake8)
        no_flake8=true
        shift 1
        ;;
      --no-yamllint)
        no_yamllint=true
        shift 1
        ;;
      -*)
        echo "Error: Unknown argument: $1" >&2
        echo "Use --help for possible arguments"
        exit 1
        ;;
      *)
        break
        ;;
    esac
done

[ -z "$target" ] && echo "target not set" && exit 1;

### Create test output directory ###
[ -d "$out_dir" ] || mkdir "$out_dir"

### Bandit check ###
# installing bandit through pip3 instead of pip causes -q (quiet) to fail
[ -z "$no_bandit" ] && printf ">> bandit...\n" && bandit -r -q -l "$target" | tee -a "$out_dir"/output_bandit

#### Python lint ###
[ -z "$no_flake8" ] && printf ">> flake8...\n" && flake8 --max-line-length=139 "$target" | tee -a "$out_dir"/output_flake8

#### Shell lint ###
if [ -z "$no_shellcheck" ]; then
  printf ">> shellcheck...\n"

  shopt -s globstar
  shellcheck --shell=bash "$target"/**/*.sh | tee -a "$out_dir"/output_shellcheck
fi

#### Yaml lint ###
[ -z "$no_yamllint" ] && printf ">> yamllint...\n" && yamllint "$target" | tee -a "$out_dir"/output_yamllint