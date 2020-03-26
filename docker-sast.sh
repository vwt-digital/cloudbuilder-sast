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

declare types
# Parse arguments
args=("$@")
while :
do
  case "$1" in
  --help)
    echo "Usage:"
    echo "positional arguments:"
    echo
    echo "--target TARGET: the target to run on. SAST-scan will automatically run recursively on folders"
    echo
    echo "optional arguments:"
    echo
    echo "--help: print usage and exit"
    echo "--type TYPE: what sast tests to run. This argument can be added multiple times (options: python, typescript)."
    echo "--context CONTEXT where this sast scan will be executed (options: commit-hook, cloudbuild)"
    echo "--no-shellcheck: disable shellcheck linter"
    echo "--no-yamllint: disable yamllint"
    echo "--no-jsonlint: disable jsonlint"
    echo
    echo "--no-trufflehog: disable trufflehog"
    echo "backend:"
    echo "--no-bandit: disable bandit scan"
    echo "--no-flake8: disable flake8 scan"
    echo
    echo "frontend:"
    echo "--no-tslint: disable tslint"
    exit 0
    ;;
  --type)
    types=( "${types[@]}" "$2" )
    shift 2
    ;;
  --target)
    target="$2"
    shift 2
    ;;
  --context)
    context="$2"
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
  --no-trufflehog)
    no_trufflehog=true
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
    echo "Error: Unknown argument: ${args[0]}" >&2
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

# Copy sast-config folder
cp -r "$target"/sast-config/. . > /dev/null 2>&1

# Execute recursively on folders
if [[ -d "$target" ]]; then
  target_type="directory"
elif [[  -f "$target" ]]; then
  target_type="file"
else
  echo "target does not exist" && exit 1
fi

# Move node_modules to workspace to hide it from passing tests
if [[ -d "$target/node_modules" ]]; then
  printf "Hide node_modules temporarily\n"
  mv "$target"/node_modules "$target"/.node_modules
fi

########################## ShellCheck ######################################
# SAST will look for .shellcheck files
if [[ -z "$no_shellcheck" ]]; then
  # If config file is found, parse arguments
  if [[ -f ".shellcheck" ]]; then
    # Add newline char to end of file to make sure it has at least one
    echo "" >> ".shellcheck"
    # Loop over lines
    while IFS= read -r line
    do
      # Loop over words
      for word in $line; do
        # Append every word as an argument
        shellcheck_args=( "${shellcheck_args[@]}" "$word" )
      done
    done < ".shellcheck"
  fi
  printf ">> shellcheck...\n";
  if [[ $target_type == "directory" ]]; then
    for f in "$target"/**/*.sh; do
       # if glob does not match, stop execution
       [[ -e "$f" ]] || continue
       eval shellcheck "${f}" --shell=bash "${shellcheck_args[@]/#}" || exit_code=1
    done
  elif [[ "${target: -3}" == ".sh" ]]; then
    shellcheck "$target" || exit_code=1
  fi
fi


########################## Yaml lint ######################################
# Yamllint looks for .yamllint, yamllint.yaml and .yamllint.yml config files by default
if [[ -z "$no_yamllint" ]]; then
  printf ">> yamllint...\n"
  if [[ $target_type == "directory" || "${target: -5}" == ".yaml" ]]; then
      yamllint "$target" -d "{extends: default, ignore: .node_modules, rules: {line-length: {max: 120}}}" || exit_code=1
  fi
fi


########################## JSONLint ######################################
# Custom jsonlint only checks if json is valid so no configuration is possible
if [[ -z "$no_jsonlint" ]]; then
  printf ">> jsonlint...\n"
  if [[ $target_type == "directory" ]]; then
      for f in "$target"/**/*.json; do
        # if glob does not match, stop execution
        [[ -e "$f" ]] || continue
        python /usr/local/bin/jsonlint.py "$f" > /dev/null 2>&1 || echo -e "\e[4m$f\e[0m"
        python /usr/local/bin/jsonlint.py "$f" || exit_code=1
      done
  elif [[ "${target: -5}" == ".json" ]]; then
    python /usr/local/bin/jsonlint.py "$target" > /dev/null 2>&1 || echo -e "\e[4m$target\e[0m"
    python /usr/local/bin/jsonlint.py "$target" || exit_code=1
  fi
fi


########################## Trufflehog ####################################
# SAST will look for a .trufflehog file
if [[ -z "$no_trufflehog" && $target_type == "directory" ]]; then
  # If config file is found, parse arguments
  if [[ -f ".trufflehog" ]]; then
    # Add newline char to end of file to make sure it has at least one
    echo "" >> ".trufflehog"
    # Loop over lines
    while IFS= read -r line
    do
      # Loop over words
      for word in $line; do
        # Append every word as an argument
        trufflehog_args=( "${trufflehog_args[@]}" "$word" )
      done
    done < ".trufflehog"
  fi
  printf  ">> trufflehog...\n"
  eval truffleHog.py --cleanup "${trufflehog_args[@]/#}" "${target}"  || exit_code=1
fi

if [[ " ${types[*]} " =~ 'python' ]]; then
############################# Bandit #####################################
  # Bandit looks for .bandit config files by default
  # installing bandit through pip3 instead of pip causes -q (quiet) to fail
  if [[ -z "$no_bandit" ]]; then
    printf ">> bandit...\n"
    if [[ $target_type == "directory" ]]; then
      bandit -r -q -l "$target" || exit_code=1
    elif [[ "${target: -3}" == ".py" ]]; then
      bandit -q -l "$target" || exit_code=1
    fi
  fi


############################# Flake8 #####################################
# Flake8 looks for setup.cfg, tox.ini and .flake8 files by default
  if [[ -z "$no_flake8" ]]; then
    printf ">> flake8...\n"
    if [[ $target_type == "directory" || "${target: -3}" == ".py" ]]; then
      flake8 --max-line-length=139 "$target" || exit_code=1
    fi
  fi
fi


if [[ -d "$target/.node_modules" ]]; then
  printf "Unhide node_modules\n"
  mv "$target"/.node_modules "$target"/node_modules
fi


if [[ " ${types[*]} " =~ 'typescript' ]]; then
############################# TSLint #####################################
# TSLint looks for tslint.json and tslint.yaml files by default
  if [[ -z "$no_tslint" ]]; then
    printf ">> tslint...\n"
    tslint --init || exit_code=1
    if [[ $target_type == "directory" ]]; then
      tslint "$target"/**/*.ts || exit_code=1
    elif [[ "${target: -3}" == ".ts" ]]; then
      tslint "$target" || exit_code=1
    fi
  fi
  # remove config file generated by tslint --init
  rm tslint.json
fi
exit $exit_code
