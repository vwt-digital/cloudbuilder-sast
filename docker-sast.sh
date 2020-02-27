#!  /usr/bin/env bash
# keep exit values after pipe: this makes it so the build step will correctly exit with error if one of the tests fails
set -o pipefail
shopt -s globstar
exit_code=0
# exit if arguments are empty
if [[ "$#" -eq 0 ]]; then
  printf "No arguments given \n"
  exit 0
fi

declare -a types
# Parse arguments
while :; do
  case "$1" in
  --help)
    echo "Usage:"
    echo "required arguments:"
    echo
    echo "--target TARGET: the target to run on. SAST-scan will automatically run recursively on folders"
    echo
    echo "optional arguments:"
    echo
    echo "--help: print usage and exit"
    echo "--type TYPE: what sast tests to run. This argument can be added multiple times (options: python, typescript)."
    echo "--no-shellcheck: disable shellcheck linter"
    echo "--no-yamllint: disable yamllint"
    echo "--no-jsonlint: disable jsonlint"
    echo
    echo "--trufflehog: TARGET: if set, will run trufflehog on TARGET (options: git url, git repo)."
    echo
    echo "backend:"
    echo "--no-bandit: disable bandit scan"
    echo "--no-flake8: disable flake8 scan"
    echo
    echo "frontend:"
    echo "--no-tslint: disable tslint"
    exit 0
    ;;
  --type)
    types=("${types[@]}" "$2")
    shift 2
    ;;
  --target)
    target=$2
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
  --trufflehog)
    trufflehog_target=$2
    shift 2
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

# Check if target is set
[ -z "$target" ] && echo "target not set" && exit 1

# Execute recursively on folders
if [[ -d "$target" ]]; then
  target_type="directory"
elif [[ -f "$target" ]]; then
  target_type="file"
else
  echo "target does not exist" && exit 1
fi

########################## ShellCheck ######################################
if [[ -z "$no_shellcheck" ]]; then
  printf ">> shellcheck...\n"
  if [[ $target_type == "directory" ]]; then
    for f in "$target"/**/*.sh; do
      # if glob does not match, stop execution
      [[ -e "$f" ]] || continue
      shellcheck "$f" --shell=bash || exit_code=1 && echo "Shellcheck FAILED"
    done
  elif [[ "${target: -3}" == ".sh" ]]; then
    shellcheck "$target" || exit_code=1 && echo "Shellcheck FAILED"
  fi
fi

########################## Yaml lint ######################################
if [[ -z "$no_yamllint" ]]; then
  printf ">> yamllint...\n"
  if [[ $target_type == "directory" || "${target: -5}" == ".yaml" ]]; then
    # Replace -d with config file if more custom rules are added
    yamllint "$target" -d "{extends: default, rules: {line-length: {max: 120}}}" || exit_code=1 && echo "Yamlcheck FAILED"
  fi
fi

########################## JSONLint ######################################
if [[ -z "$no_jsonlint" ]]; then
  printf ">> jsonlint...\n"
  if [[ $target_type == "directory" ]]; then
    for f in "$target"/**/*.json; do
      # if glob does not match, stop execution
      [[ -e "$f" ]] || continue
      jsonlint -q "$f" || echo "Error in file: $f" && exit_code=1 && echo "JSONLint FAILED"
    done
  elif [[ "${target: -5}" == ".json" ]]; then
    jsonlint -q "$target" || exit_code=1 && echo "JSONLint FAILED"
  fi
fi

########################## Trufflehog ####################################
if [[ -n "$trufflehog_target" ]]; then
  printf ">> trufflehog...\n"
  trufflehog --cleanup --entropy=true "$trufflehog_target" || exit_code=1 && echo "Trufflehog FAILED"
fi

if [[ " ${types[*]} " =~ 'python' ]]; then
  ############################# Bandit #####################################
  # installing bandit through pip3 instead of pip causes -q (quiet) to fail
  if [[ -z "$no_bandit" ]]; then
    printf ">> bandit...\n"
    if [[ $target_type == "directory" ]]; then
      bandit -r -q -l "$target" || exit_code=1 && echo "Bandit FAILED"
    elif [[ "${target: -3}" == ".py" ]]; then
      bandit -q -l "$target" || exit_code=1 && echo "Bandit FAILED"
    fi
  fi

  ############################# Flake8 #####################################
  if [[ -z "$no_flake8" ]]; then
    printf ">> flake8...\n"
    if [[ $target_type == "directory" || "${target: -3}" == ".py" ]]; then
      flake8 --max-line-length=139 "$target" || exit_code=1 && echo "Flake8 FAILED"
    fi
  fi
fi

if [[ " ${types[*]} " =~ 'typescript' ]]; then
  ############################# TSLint #####################################
  if [[ -z "$no_tslint" ]]; then
    printf ">> tslint...\n"
    tslint --init || exit_code=1 && echo "TSLint FAILED"
    if [[ $target_type == "directory" ]]; then
      tslint "$target"/**/*.ts || exit_code=1 && echo "TSLint FAILED"
    elif [[ "${target: -3}" == ".ts" ]]; then
      tslint "$target" || exit_code=1 && echo "TSLint FAILED"
    fi
  fi
  # remove config file generated by tslint --init
  rm tslint.json
fi

exit $exit_code
