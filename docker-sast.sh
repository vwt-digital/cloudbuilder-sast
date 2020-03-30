#!  /usr/bin/env bash
# shellcheck disable=SC2164
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
    echo "--type TYPE: what sast tests to run. This argument can be added multiple times (options: python, typescript)"
    echo "--context CONTEXT where this sast scan will be executed (options: commit-hook, cloudbuild)"
    echo
    echo "--config: add config file, which can include the following flags:"
    echo
    echo "    --no-shellcheck: disable shellcheck"
    echo "    --no-jsonlint: disable jsonlint"
    echo "    --no-yamllint: disable yamllint"
    echo "    --no-trufflehog: disable trufflehog"
    echo "    --no-bandit: disable bandit"
    echo "    --no-flake8: disable falke8"
    echo "    --no-eslint: disable ESlint"
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
  --config)
    config_file=$2
    shift 2
    ;;
  --context)
    context="$2"
    shift 2
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

# Copy sast-config folder
cp -r "$target"/sast-config/. . > /dev/null 2>&1
# Read sast-config file

if [[ -n "$config_file" ]]; then
  if [[  -f "$config_file" ]]; then
    # Add newline char to end of file to make sure it has at least one
    echo "" >> "$config_file"

    while IFS= read -r line; do
        # Loop over words
        for word in $line; do
          # Append every word as an argument
          [[ "$word" == "--no-shellcheck" ]] && no_shellcheck=true
          [[ "$word" == "--no-jsonlint" ]] && no_jsonlint=true
          [[ "$word" == "--no-yamllint" ]] && no_yamllint=true
          [[ "$word" == "--no-trufflehog" ]] && no_trufflehog=true
          [[ "$word" == "--no-bandit" ]] && no_bandit=true
          [[ "$word" == "--no-flake8" ]] && no_flake8=true
          [[ "$word" == "--no-estslint" ]] && no_eslint=true
        done
      done < "$config_file"
  else
    echo "target is not a file or does not exist" && exit 1
  fi
fi
# Execute recursively on folders
if [[ -d "$target" ]]; then
  target_type="directory"
elif [[  -f "$target" ]]; then
  target_type="file"
else
  echo "target does not exist" && exit 1
fi
if  [[ -n ${context+x} ]]; then
  if [[ "$context" == "commit-hook" ]]; then
    echo "$context"
  elif [[ "$context" == "cloudbuild" ]]; then
    echo "$context"
  fi
fi

# Hide node_modules
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
    while IFS= read -r line; do
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
  # installing bandit thr ough pip3 instead of pip causes -q (quiet) to fail
  if [[ -z "$no_bandit" ]]; then
    printf ">> bandit...\n"
    if [[ $target_type == "directory" ]]; then
      bandit -r -q -l "$target" -x .node_modules|| exit_code=1
    elif [[ "${target: -3}" == ".py" ]]; then
      bandit -q -l "$target" || exit_code=1
    fi
  fi


############################# Flake8 #####################################
# Flake8 looks for setup.cfg, tox.ini and .flake8 files by default
  if [[ -z "$no_flake8" ]]; then
    printf ">> flake8...\n"
    if [[ $target_type == "directory" ]]; then
      flake8 --max-line-length=139 "$target" --exclude .node_modules || exit_code=1
    elif [[ "${target: -3}" == ".py" ]];then
      flake8 --max-line-length=139 "$target" || exit_code=1
    fi
  fi
fi


if [[ -d "$target/.node_modules" ]]; then
  printf "Unhide node_modules\n"
  mv "$target"/.node_modules "$target"/node_modules
fi


if [[ " ${types[*]} " =~ 'typescript' ]]; then
############################# ESLint #####################################
  if [[ -z "$no_eslint" ]]; then
    printf ">> eslint...\n"
    if [[ "$target_type" == "directory" ]]; then
      if ls "$target"/*.ts >/dev/null 2>&1; then
        [ -d "$target" ] && cd "$target"; exit_code=1
        esconf=eslintrc.json
        if [[ ! -f "$esconf" ]]; then
          mv /usr/local/etc/eslintrc.json eslintrc.json
        fi
        eslint . -c eslintrc.json --ext .ts || exit_code=1
        cd /
      fi
    fi
  fi
fi
exit $exit_code
