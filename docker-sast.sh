#! /usr/bin/env bash

# keep exit values after pipe: this makes it so the build step will correctly exit with error if one of the tests fails
set -o pipefail
shopt -s globstar
exit_code=0

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
    echo "--type: what sast test to run (options: python, typescript)"
    echo "--target: the target to run on"
    echo
    echo "optional arguments:"
    echo
    echo "--help: print usage and exit"
    echo "--out_dir: location for output files (Default: \$pwd/sast_output)"
    echo "--no_shellcheck: disable shellcheck linter"
    echo "--no_yamllint: disable yamllint linter"
    echo "--no-jsonlint: disable jsonlint"
    echo
    echo "backend:"
    echo "--no_bandit: disable bandit scan"
    echo "--no_flake8: disable flake8 scan"
    echo
    echo "frontend:"
    echo "--no_tslint: disable tslint"
    exit 0
    ;;
  --type)
    type=$2
    shift 2
    ;;
  --target)
    target=$2
    shift 2
    ;;
  --out_dir)
    out_dir=$2
    shift 2
    ;;
  --no-shellcheck)
    no_shellcheck=true
    shift 1
    ;;
  --no-jsonlint)
    no_jsonlint=true
    shift 1
    ;;
  --no-yamllint)
    no_yamllint=true
    shift 1
    ;;
  --no-flake8)
    no_flake8=true
    shift 1
    ;;
  --no-bandit)
    no_bandit=true
    shift 1
    ;;
  --no-tslint)
    no_tslint=true
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

[ -z "$target" ] && echo "target not set" && exit 1

### Create test output directory ###
[ -d "$out_dir" ] || mkdir "$out_dir"

### Shell lint ###
[ -z "$no_shellcheck" ] && printf ">> shellcheck...\n" && find "$target" -name "*.sh" -exec shellcheck {} --shell=bash \;| tee -a "$out_dir"/output_shellcheck || exit_code=1

### Yaml lint ###
[ -z "$no_yamllint" ] && printf ">> yamllint...\n" && yamllint "$target" | tee -a "$out_dir"/output_yamllint || exit_code=1

### jsonlint ###
[ -z "$no_jsonlint" ] && printf ">> jsonlint...\n" && find "$target" -name "*.json" -exec jsonlint {} -q \; || exit_code=1
if [[ "$type" == 'python' ]]; then
  ### Bandit check ###
  # installing bandit through pip3 instead of pip causes -q (quiet) to fail
  [ -z "$no_bandit" ] && printf ">> bandit...\n" && bandit -r -q -l "$target"/**/*.py | tee -a "$out_dir"/output_bandit || exit_code=1

  ### Python lint ###
  [ -z "$no_flake8" ] && printf ">> flake8...\n" && flake8 --max-line-length=139 "$target" | tee -a "$out_dir"/output_flake8 || exit_code=1
fi

if [[ "$type" == 'typescript' ]]; then
  ### typescript linter ###
  [ -z "$no_tslint" ] && printf ">> tslint...\n" && tslint --init && tslint "$target"/**/*.ts || exit_code=1
fi

exit $exit_code