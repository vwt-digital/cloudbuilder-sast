#!  /usr/bin/env bash
# TODO: fix these
# shellcheck disable=SC2164
# shellcheck disable=SC2006
# keep exit values after pipe: this makes it so the build step will correctly exit with error if one of the tests fails
set -o pipefail
shopt -s globstar
exit_code=0

target="/sast-files"

# Parse arguments
while :
do
  case "$1" in
  --help)
    echo "Usage:"
    echo "positional arguments:"
    echo
    echo "--target TARGET: the target to run on. SAST-scan will automatically run recursively on folders. Will default to /sast-files if no target is set."
    echo
    echo "optional arguments:"
    echo
    echo "--help: print usage and exit"
    echo "--context CONTEXT where this sast scan will be executed (options: commit-hook, cloudbuild)"
    exit 0
    ;;
  --target)
    target="$2"
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

# Execute recursively on folders
if [[ -d "$target" ]]; then
  target_type="directory"
  directory_copy="/directory"
  rm -rf "/directory"
  cp -r "$target" "$directory_copy"
  cd "$directory_copy" && target=.
elif [[  -f "$target" ]]; then
  target_type="file"
else
  echo "target $target does not exist" && exit 1
fi

# Copy sast-config folder
if [[ $target_type == "directory" && -d "$target/sast-config" ]]; then
  shopt -s dotglob
  mv "$target"/sast-config/* .
  shopt -u dotglob
fi

# Read sast-config file (.sast by default)
if [[  -f ".sast" ]]; then
  config_file=".sast"
elif [[ -f ".sast-config" ]]; then
  config_file=".sast-config"
fi

if [[ -n "$config_file" ]]; then
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
        [[ "$word" == "--no-eslint" ]] && no_eslint=true
      done
    done < "$config_file"
fi

if  [[ -n ${context+x} ]]; then
  if [[ "$context" == "pre-commit" ]]; then
    no_trufflehog=true
  elif [[ "$context" == "post-commit" ]]; then
    no_shellcheck=true
    no_jsonlint=true
    no_yamllint=true
    no_bandit=true
    no_flake8=true
    no_eslint=true
  elif [[ "$context" == "cloudbuild" ]]; then
    :
  fi
fi

# Hide node_modules
if [[ -d "$target/node_modules" ]]; then
  printf "Hide node_modules temporarily\n"
  mv "$target"/node_modules "$target"/.node_modules
else
  echo "No node_modules found"
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
else
  echo "Skipping shellcheck..."
fi


########################## Yaml lint ######################################
# Yamllint looks for .yamllint, .yamllint.yaml and .yamllint.yml config files by default
if [[ -f ".yamllint" ]]; then
  yamllint_config=".yamllint"
elif [[ -f ".yamllint.yaml" ]]; then
  yamllint_config=".yamllint.yaml"
elif [[ -f ".yamllint.yml" ]]; then
  yamllint_config=".yamllint.yml"
fi
if [[ -n $yamllint_config ]]; then
  yamllint_config_arg="-c${yamllint_config}"
else
  yamllint_config_arg="-d {extends: default, ignore: .node_modules, rules: {line-length: {max: 120}}}"
fi
if [[ -z "$no_yamllint" ]]; then
  printf ">> yamllint...\n"
  if [[ $target_type == "directory" || "${target: -5}" == ".yaml" ]]; then
      yamllint "$target" "${yamllint_config_arg}" || exit_code=1
  fi
else
  echo "Skipping yamllint..."
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
else
  echo "Skipping jsonlint..."
fi

########################## Trufflehog ####################################
# SAST will look for a .trufflehog file
if [[ -z "$no_trufflehog" && $target_type == "directory" && -a "$target/.git" ]]; then
  echo ">> Recursively checking trufflehog:"
  while IFS=$'\n' read -r d
  do
    cd "$d"
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
    git_url=$(git config --get remote.origin.url)
    if [ -z "$git_url" ]
    then
      git_url="local repository"
    fi
    printf  ">> running trufflehog on %s in %s ...\n" "$git_url" "$d"
    thrules=thrules.json
    if [[ ! -f "$thrules" ]]; then
      cp /usr/local/etc/thrules.json thrules.json
    fi
    eval python3 /usr/local/bin/truffleHog.py --regex --cleanup --max_depth=1 "${trufflehog_args[@]/#}" "${target}" --rules thrules.json  || exit_code=1
    cd "$target"
  done< <(find . -name .git -type d -exec dirname {} \;)
else
  echo "Skipping trufflehog..."
fi


############################# Bandit #####################################
# Bandit looks for .bandit config files by default
# installing bandit through pip3 instead of pip causes -q (quiet) to fail

if [[ -z "$no_bandit" ]]; then
  printf ">> bandit...\n"
  if [[ $target_type == "directory" ]]; then
    if [[ ! -f ".bandit" ]]; then
      bandit -r -q -l -x "$target"/.node_modules -s B105 "$target"|| exit_code=1
    else
      bandit -r -q -l "$target" || exit_code=1
    fi
  elif [[ "${target: -3}" == ".py" ]]; then
    bandit -q -l "$target" || exit_code=1
  fi
else
  echo "Skipping bandit..."
fi


############################# Flake8 #####################################
# Flake8 looks for setup.cfg, tox.ini and .flake8 files by default
if [[ -z "$no_flake8" ]]; then
  printf ">> flake8...\n"
  if [[ $target_type == "directory" ]]; then
    if [[ ! -f ".flake8" && ! -f "tox.ini" && ! -f "setup.cfg" ]]; then
      flake8 --max-complexity=10 --ignore=E203,W503 --max-line-length=139 "$target" --exclude .node_modules || exit_code=1
    else
      flake8 "$target" || exit_code=1
    fi

  elif [[ "${target: -3}" == ".py" ]];then
    flake8 --max-complexity=10 --ignore=E203,W503 --max-line-length=139 "$target" || exit_code=1
  fi
else
  echo "Skipping flake8..."
fi


if [[ -d "$target/.node_modules" ]]; then
  printf "Unhide node_modules\n"
  mv "$target"/.node_modules "$target"/node_modules
fi


############################# ESLint #####################################
if [[ -z "$no_eslint" ]]; then
  printf ">> eslint...\n"
  if [[ "$target_type" == "directory" ]]; then
    if [[ `find "$target" -type f -name "*.ts" -not -path "$target/node_modules/*"` && -d "$target"/node_modules ]]; then
      esconf=eslintrc.json
      if [[ ! -f "$esconf" ]]; then
        cp /usr/local/etc/eslintrc.json eslintrc.json
      fi
      eslint . -c eslintrc.json --ext .ts || exit_code=1
    fi
  fi
else
  echo "Skipping eslint..."
fi
[[ $target_type == "directory" ]] && cd /
exit $exit_code
