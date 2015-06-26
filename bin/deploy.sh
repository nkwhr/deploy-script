#!/bin/bash

set -e

now=$(date '+%Y%m%d-%H%M%S')
tmpdir="/var/tmp/${app_name}"

app_name="test"
release_name="${now}"

stat_latest="${tmpdir}/.latest_revision"
stat_last="${tmpdir}/.last_revision"

git_user="git"
git_server="localhost"
git_options=""
git_repo="/home/git/repo/test.git"

remote_user="app"
remote_host="localhost"
remote_deploy_path="/var/www/#{app_name}/releases"
remote_app_current="/var/www/#{app_name}/current"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function die() {
  kill -INT $$
}

function info() {
  local _message=$1
  printf "${GREEN}* INFO: ${_message}${NC}\n"
}

function error() {
  local _message=$1
  printf "${RED}* ERROR: ${_message}${NC}\n"
  die
}

function clone_latest() {
  echo "${release_name}" > "${stat_latest}"
  git clone ${git_options} ${git_user}@${git_server}:${git_repo} "${tmpdir}/${release_name}"
}

function check_latest_revision() {
  local _revision=$(cat "${stat_latest}" 2>/dev/null)

  if [ "x" == "x${_revision}" ] ; then
    error "Could not find revision info for the latest release. Run \`$0 clone\` to prepare deployment."
  fi
}

function _is_deployed() {
  local _revision=$1

  retval=$(ssh ${remote_user}@${remote_host} "test -e ${remote_deploy_path}/${_revision} && echo 0 || echo 1")
  return "${retval}"
}

function deploy() {
  local _rsync_options=$1

  local _revision=$(cat "${stat_latest}" 2>/dev/null)
  local _deploy_target="${tmpdir}/${_revision}"

  if [ -e "${_deploy_target}" ] ; then
    ssh ${remote_user}@${remote_host} "mkdir -p {remote_deploy_path}"
    rsync -Haxv "${_rsync_options}" --exclude=".git" "${_deploy_target} ${remote_user}@${remote_host}:${remote_deploy_path}"
  else
    error "${_deploy_target} does not exist."
  fi
}

function release() {
  local _release_revision=$(cat "${stat_latest}" 2>/dev/null)

  _is_deployed "${_release_revision}" || error "${_release_revision} has not yet been deployed to remote host."

  local _current_release=$(ssh ${remote_user}@${remote_host} "ls -l ${remote_app_current} | awk '{print \$11}'")
  local _current_revision=$(basename "${_current_release}")

  if [ "${_current_revision}" = "${_release_revision}" ] ; then
     error "${_release_revision} is already released."
  fi

  echo "${_current_revision}" > "${stat_last}"

  info "${_current_revision} ---> ${_release_revision}"
  ssh ${remote_user}@${remote_host} "rm ${remote_app_current} 2>/dev/null ; ln -s ${remote_deploy_path}/${_release_revision} ${remote_app_current}"
}

function rollback() {
  local _rollback_revision=$(cat "${stat_last}" 2>/dev/null)

  if [ "x" == "x${_rollback_revision}" ] ; then
    error "Could not determine which revision to rollback."
  fi

  _is_deployed "${_rollback_revision}" || error "${_rollback_revision} was not found in remote host."

  local _current_release=$(ssh ${remote_user}@${remote_host} "ls -l ${remote_app_current} | awk '{print \$11}'")
  local _current_revision=$(basename "${_current_release}")

  if [ "${_current_revision}" = "${_rollback_revision}" ] ; then
     error "${_rollback_revision} is already released."
  fi

  info "${_current_revision} ---> ${_rollback_revision}"
  ssh ${remote_user}@${remote_host} "rm ${remote_app_current} && ln -s ${remote_deploy_path}/${_rollback_revision} ${remote_app_current}"
}

argv=$1

case $argv in
  clone)
    info "Cloning latest release to ${tmpdir}/${deploy_repo}"
    clone_latest && info "done\n" || error "failed\n"
    ;;
  test)
    info "Testing deployment to ${remote_host}"
    check_latest_revision
    deploy "--dry-run" && info "done\n" || error "failed\n"
    ;;
  deploy)
    info "Deploying latest release to ${remote_host}"
    check_latest_revision
    deploy && info "done\n" || error "failed\n"
    ;;
  release)
    info "Switching release to latest revision"
    check_latest_revision
    release && info "done.\n" || error "failed\n"
    ;;
  rollback)
    info "Switching back release to last revision"
    rollback && info "done.\n" || error "failed\n"
    ;;
  *)
    echo "Usage: $0 (clone|test|deploy|release|rollback)"
    echo
    echo "  clone    : Clone latest release from git repository"
    echo "  test     : Dry run deployment to remote host"
    echo "  deploy   : Deploy a latest release to remote host"
    echo "  release  : Switch application to deployed release"
    echo "  rollback : Switch back to last release"
    echo
    exit 1
esac
