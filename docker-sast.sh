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

#possible_args=("--target" "--help" "--type" "--config" "--no-shellcheck" "--no-yamllint" "--no-jsonlint" "--trufflehog" "--no-bandit" "--no-flake8" "--no-tslint")

declare types
# Parse arguments
args=("$@")
while :
do
  case "${args[0]}" in
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
    echo "--config FILE: location of a config file. See README for instructions."
    echo "--no-shellcheck: disable shellcheck linter"
    echo "--no-yamllint: disable yamllint"
    echo "--no-jsonlint: disable jsonlint"
    echo
#    echo "--trufflehog ARGUMENTS: if set, will parse arguments as trufflehog arguments until it finds a docker-sast"\
#         "argument"
#    echo "                        e.g. $ docker-sash.sh --trufflehog --cleanup /git_folder --target /git_folder"
#    echo
    echo "backend:"
    echo "--no-bandit: disable bandit scan"
    echo "--no-flake8: disable flake8 scan"
    echo
    echo "frontend:"
    echo "--no-tslint: disable tslint"
    exit 0
    ;;
   --config)
    config_file=${args[1]}
    # Check if config file exists
    [ ! -f "$config_file" ] && echo "config does not exist" && exit 1
    # Add newline char to end of file to make sure it has at least one
    echo "" >> "$config_file"
    # Loop over lines
    while IFS= read -r line
    do
      # Loop over words
      for word in $line; do
        # Append every word as an argument
        args=( "${args[@]}" "$word" )
      done
    done < "$config_file"
    args=( "${args[@]:2}" )
    ;;
  --type)
    types=( "${types[@]}" "${args[1]}" )
    args=( "${args[@]:2}" )
    ;;
  --target)
    target=${args[1]}
    args=( "${args[@]:2}" )
    ;;
  --no-shellcheck)
    no_shellcheck=true
    args=( "${args[@]:1}" )
    ;;
  --no-jsonlint)
    no_jsonlint=true
    args=( "${args[@]:1}" )
    ;;
  --no-yamllint)
    no_yamllint=true
    args=( "${args[@]:1}" )
    ;;
#  --trufflehog)
#    args=( "${args[@]:1}" )
#    trufflehog=true
#    trufflehog_arguments=()
#    while [[ ! ${possible_args[*]} == *${args[0]}* ]]; do
#      trufflehog_arguments+=("${args[0]}")
#      args=( "${args[@]:1}" )
#    done
#    ;;
  # For the sake of backwards compatability --no-trufflehog overrides --trufflehog
#  --no-trufflehog)
#    no_trufflehog=true
#    args=( "${args[@]:1}" )
#    ;;
  --no-flake8)
    no_flake8=true
    args=( "${args[@]:1}" )
    ;;
  --no-bandit)
    no_bandit=true
    args=( "${args[@]:1}" )
    ;;
  --no-tslint)
    no_tslint=true
    args=( "${args[@]:1}" )
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

# Execute recursively on folders
if [[ -d "$target" ]]; then
  target_type="directory"
elif [[  -f "$target" ]]; then
  target_type="file"
else
  echo "target does not exist" && exit 1
fi

########################## ShellCheck ######################################
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
      # Replace -d with config file if more custom rules are added
      yamllint "$target" -d "{extends: default, rules: {line-length: {max: 120}}}" || exit_code=1
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
        python /usr/local/bin/jsonlint.py "$f" || exit_code=1;
      done
  elif [[ "${target: -5}" == ".json" ]]; then
    python /usr/local/bin/jsonlint.py "$target" > /dev/null 2>&1 || echo -e "\e[4m$target\e[0m"
    python /usr/local/bin/jsonlint.py "$target" || exit_code=1
  fi
fi


########################## Trufflehog ####################################
#if [[ -n "$trufflehog" && -z "$no_trufflehog" ]]; then
#  printf  ">> trufflehog...\n"
#  trufflehog "${trufflehog_arguments[@]}" || exit_code=1
#fi


if [[ " ${types[*]} " =~ 'python' ]]; then
############################# Bandit #####################################
  # Bandit looks for .bandit config files by default
  # installing bandit through pip3 instead of pip causes -q (quiet) to fail
  if [[ -z "$no_bandit" ]]; then
    printf ">> bandit...\n"
    if [[ $target_type == "directory" ]]; then
      eval bandit -r -q -l "${target}" "${bandit_config}" || exit_code=1
    elif [[ "${target: -3}" == ".py" ]]; then
      eval bandit -q -l "${target}" "${bandit_config}"|| exit_code=1
    fi
  fi


############################# Flake8 #####################################
  if [[ -z "$no_flake8" ]]; then
    printf ">> flake8...\n"
    if [[ $target_type == "directory" || "${target: -3}" == ".py" ]]; then
      flake8 --max-line-length=139 "$target" || exit_code=1
    fi
  fi
fi


if [[ " ${types[*]} " =~ 'typescript' ]]; then
############################# TSLint #####################################
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
