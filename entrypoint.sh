#!/bin/bash

function debug() {
    echo "::debug file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function warning() {
    echo "::warning file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function error() {
    echo "::error file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function add_mask() {
    echo "::add-mask::$1"
}
###############################################################################
## Check required inputs that don't have defaults
###############################################################################
if [ -z "$SOURCE" ]; then
  error "SOURCE environment variable is not set"
  exit 1
fi

if [ -z "$DESTINATION" ]; then
  error "DESTINATION environment variable is not set"
  exit 1
fi

if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
  error "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is not set"
  exit 1
fi

if [ "$SOURCE" = "wiki" ]; then
  SYNC_DIRECTORY=$DESTINATION
elif [ "$DESTINATION" = "wiki" ]; then
  SYNC_DIRECTORY=$SOURCE
else 
  error "Either SOURCE or DESTINATION must be set to 'wiki'"
  exit 1
fi

add_mask "${GITHUB_PERSONAL_ACCESS_TOKEN}"

###############################################################################
## Check optional inputs that don't have defaults
###############################################################################
if [ -z "${GIT_AUTHOR_EMAIL:-}" ]; then
    debug "GIT_AUTHOR_EMAIL not set, using default"
    GIT_AUTHOR_EMAIL="$GIT_AUTHOR_NAME@users.noreply.github.com"
fi

if [ -z "${WIKI_COMMIT_MESSAGE:-}" ]; then
    debug "WIKI_COMMIT_MESSAGE not set, using default"
    WIKI_COMMIT_MESSAGE="chore(docs): Sync $SOURCE to $DESTINATION [skip-cd]"
fi

###############################################################################
## Set wiki repo URL
###############################################################################
if [ -z "$GITHUB_REPOSITORY" ]; then
    error "GITHUB_REPOSITORY environment variable is not set"
    exit 1
fi
GIT_REPOSITORY_URL="https://${GITHUB_PERSONAL_ACCESS_TOKEN}@github.com/$GITHUB_REPOSITORY.wiki.git"


###############################################################################
## Check out wiki
###############################################################################
debug "Checking out wiki repository"
tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
(
  cd "$tmp_dir" || exit 1
  git init
  git config user.name "$GIT_AUTHOR_NAME"
  git config user.email "$GIT_AUTHOR_EMAIL"
  git pull "$GIT_REPOSITORY_URL"
)

###############################################################################
## Sync files if there's a diff between source and destination
###############################################################################
debug "Checking diff between $SOURCE and $DESTINATION"

# diff returns -1 if there are differences, which exits 
# the workflow. || is used to bypass this exiting prematurely
DIFF=$(diff -qr --exclude=.git $SYNC_DIRECTORY $tmp_dir || true) 

if [ "$DIFF" != "" ]; then
  debug "Syncing contents of $SOURCE to $DESTINATION"

  # Check which direction the sync is occurring
  if [ "$DESTINATION" = "wiki" ]; then # $SOURCE -> wiki
    rsync -avzr --delete --exclude='.git/' "$SOURCE/" "$tmp_dir"
    debug "Committing and pushing changes"
    (
        cd "$tmp_dir" || exit 1
        ### Workaround: add github workspace as safe directory
        git config --global --add safe.directory "$tmp_dir"
        git add .
        git commit -m "$WIKI_COMMIT_MESSAGE"
        git push --set-upstream "$GIT_REPOSITORY_URL" master
    )
  else # wiki -> $DESTINATION
    rsync -avzr --delete --exclude='.git/' "$tmp_dir/" "$DESTINATION"
    debug "Committing and pushing changes"
    (
      git config --global user.name "$GIT_AUTHOR_NAME"
      git config --global user.email "$GIT_AUTHOR_EMAIL"

      ### Workaround: add github workspace as safe directory
      git config --global --add safe.directory "$GITHUB_WORKSPACE"
      
      # develop could have been modified by the time we get here, so pull before pushing
      # Maybe don't need if we checkout develop...
      # git pull --ff-only origin develop
      
      git add .
      git commit -m "$WIKI_COMMIT_MESSAGE"
      git push origin $BRANCH
    )
  fi
else 
    warning "No file diff between $SOURCE and $DESTINATION. Exiting."
fi 

rm -rf "$tmp_dir"
debug "Finished - $SOURCE synced to $DESTINATION"
exit 0
