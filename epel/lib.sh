#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = epel
#   library-version = 33
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_epel_LIB_VERSION=33
__INTERNAL_epel_LIB_NAME='distribution/epel'
: <<'=cut'
=pod

=head1 NAME

BeakerLib library distribution/epel

=head1 DESCRIPTION

This library adds disabled epel repository.

=head1 USAGE

To use this functionality you need to import library distribution/epel and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/epel)" >> $(METADATA)

The repo is installed by epel-release package so it creates repo named epel,
epel-debuginfo, and epel-source, and the testing ones. All of them are disabled
by the library. To use them you should call yum with --enablerepo option, e.g.
'--enablerepo epel'. But be sure epel is avaivalbe, otherwise the repo is
unknown to yum.

Alternatively you can call C<epelyum>  or C<epel yum> instead of
C<yum --enablerepo epel> which
would work also if epel is not available or C<epel yum>. For example on Fedora.
Or use I<epelIsAvailable> to check actual availability of the epel repo.

=head1 VARIABLES

=cut


epelRepoFiles=''
epelInternalRepoFile=/etc/yum.repos.d/epel-internal.repo
__INTERNAL_epel_curl="curl --fail --location --retry-delay 3 --retry-max-time 3600 --retry 3 --connect-timeout 20 --max-time 1800 --insecure -o"
rlIsRHEL '<8' || __INTERNAL_epel_curl="curl --fail --location --retry-connrefused --retry-delay 3 --retry-max-time 3600 --retry 3 --connect-timeout 20 --max-time 1800 --insecure -o"
: <<'=cut'
=pod

=head1 FUNCTIONS

=cut
echo -n "loading library $__INTERNAL_epel_LIB_NAME v$__INTERNAL_epel_LIB_VERSION... "


epelBackupRepos() {
  rlFileBackup --namespace epel_lib_repos --clean $epelRepoFiles
}


epelRestoreRepos() {
  rlFileRestore --namespace epel_lib_repos
}


epelSetup() {
  epelBackupRepos
}


epelCleanup() {
  epelRestoreRepos
}


# useful for noarch packages on unsupported architectures
# example:
#   epelBackupRepos
#   epelSetArch x86_64
#   yum ...
#   epelRestoreRepos
epelSetArch() {
  rlLog "setting fake architecture to $1"
  for i in $epelRepoFiles ; do
    sed -ri "s/arch=[^&]*/arch=$1/" "$i"
  done
}


epelDisableMainRepo() {
  rlLog "disabling epel repo"
  epelInternalIsAvailable && epelDisableRepos $epelInternalRepoFile
  yum-config-manager --disable epel
}


epelEnableMainRepo() {
  rlLog "enabling epel repo"
  epelInternalIsAvailable && epelEnableRepos $epelInternalRepoFile
  yum-config-manager --enable epel
}


epelDisableRepos() {
  epelEnableRepos "$1" 0
}


epelEnableRepos() {
  local repos="$1"
  local enable=1
  if [[ -z "$2" ]]; then
    rlLog "enabling epel repos"
  else
    rlLog "disabling epel repos"
    enable=0
  fi
  [[ -z "$repos" ]] && repos="$epelRepoFiles"
  for i in $repos ; do
    rlLogDebug "processing $i"
    rlLogDebug "  repo file before"
    rlLogDebug "$(cat $i)"
    sed -ri "s/enabled=./enabled=$enable/" "$i"
    rlLogDebug "  repo file after"
    rlLogDebug "$(cat $i)"
  done
}


epelIsAvailable() {
  [[ -n "$__INTERNAL_epelIsAvailable" ]]
}


epelInternalIsAvailable() {
  [[ -s "$epelInternalRepoFile" ]]
}


epelyum() {
    epel yum "$@"
}


epel() {
    local enablerepo command="$1"; shift
    epelIsAvailable && enablerepo='--enablerepo epel'
    epelInternalIsAvailable && enablerepo+=' --enablerepo epel-internal'
    echo "actually running '$command $enablerepo $*'" >&2
    $command $enablerepo "$@"
}


__INTERNAL_epelCheckRepoAvailability() {
  rlLogDebug "$FUNCNAME(): try to access the repository to check availability"
  local vars sed_pattern url repo type res=0
  local cache="/var/tmp/beakerlib_library(distribution_epel)_available"
  [[ -r "$cache" ]] && {
    res="$(cat "$cache")"
    rlLogDebug "$FUNCNAME(): found chached result '$res'"
    [[ -n "$res" ]] && {
     [[ $res -eq 0 ]] && rlLog "epel repo is accessible" || rlLog "epel repo is not accessible"
      return $res
    }
    rlLogDebug "$FUNCNAME(): bad cached result"
  }
  if which python >& /dev/null; then
    rlLogDebug "$FUNCNAME(): running python to get repo file variables substitution"
    vars=$(python -c 'import yum, pprint; yb = yum.YumBase(); pprint.pprint(yb.conf.yumvar, width=1)' 2> /dev/null)
  elif [[ -x /usr/libexec/platform-python ]]; then
    rlLogDebug "$FUNCNAME(): running /usr/libexec/platform-python to get repo file variables substitution"
    vars=$(/usr/libexec/platform-python -c 'import dnf, pprint; db = dnf.dnf.Base(); pprint.pprint(db.conf.substitutions,width=1)' 2> /dev/null)
  elif which python3 >& /dev/null; then
    rlLogDebug "$FUNCNAME(): running python3 to get repo file variables substitution"
    vars=$(python3 -c 'import dnf, pprint; db = dnf.dnf.Base(); pprint.pprint(db.conf.substitutions,width=1)' 2> /dev/null)
  else
    rlLogError "could not resolve yum repo variables"
    return 1
  fi
  rlLogDebug "$FUNCNAME(): $(declare -p vars)"
  sed_pattern=$(echo "$vars" | grep -Eo "'[^']+':[^']+'[^']+'" | sed -r "s|'([^']+)'[^']+'([^']+)'|s/\\\\\$\1/\2/g;|" | tr -d '\n')
  rlLogDebug "$(declare -p sed_pattern)"
  repo=$(grep --no-filename '^[^#]'  $epelRepoFiles | grep -v 'testing' | grep -E -m1 'baseurl|mirrorlist|metalink')
  rlLogDebug "$FUNCNAME(): $(declare -p repo)"
  [[ -z "$repo" ]] && {
    rlLogError "$FUNCNAME(): cloud not get repo URL!!!"
    let res++
  }
  if [[ "$repo" =~ $(echo '^([^=]+)=(.+)') ]]; then
    type="${BASH_REMATCH[1]}"
    url="$(echo "${BASH_REMATCH[2]}" | sed -r "$sed_pattern")"
    rlLogDebug "$FUNCNAME(): $(declare -p type)"
    rlLogDebug "$FUNCNAME(): $(declare -p url)"
    case $type in
    baseurl)
      rlLogDebug "$FUNCNAME(): download repodata to check availability"
      rlLogDebug "$FUNCNAME(): running '$__INTERNAL_epel_curl - \"$url/repodata\" | grep -q 'repomd\.xml''"
      local tmp=$($__INTERNAL_epel_curl - "$url/repodata") || let res++
      echo "$tmp" | grep -q 'repomd\.xml' || let res++
      ;;
    mirrorlist|metalink)
      rlLogDebug "$FUNCNAME(): download mirrorlist/metalink to check availability"
      rlLogDebug "$FUNCNAME(): running '$__INTERNAL_epel_curl - \"$url\" | grep -qE '^http|repomd\.xml''"
      local tmp=$($__INTERNAL_epel_curl - "$url") || let res++
      echo "$tmp" | grep -qE '^http|repomd\.xml' || let res++
      ;;
    esac
  else
    rlLogDebug "$FUNCNAME(): could not parse repo"
    let res++
  fi
  [[ $res -eq 0 ]] && rlLog "epel repo is accessible" || rlLog "epel repo is not accessible"
  rlLogDebug "$FUNCNAME(): returning '$res'"
  echo "$res" > "$cache"
  return $res
}


__INTERNAL_epelRepoFiles() {
  epelRepoFiles="$(rpm -ql epel-release | grep '/etc/yum.repos.d/.*\.repo' | tr '\n' ' ')"
  [[ -z "$epelRepoFiles" ]] && {
    epelRepoFiles="$(grep -il '\[epel[^]]*\]' /etc/yum.repos.d/*.repo | tr '\n' ' ')"
  }
  epelInternalIsAvailable && epelRepoFiles+=" $epelInternalRepoFile"
  rlLogDebug "$FUNCNAME(): $(declare -p epelRepoFiles)"
  if [[ -n "$epelRepoFiles" ]]; then
    __INTERNAL_epelCheckRepoAvailability && __INTERNAL_epelIsAvailable=1
    return 0
  else
    rlLogDebug "$FUNCNAME(): no repo files found"
    return 1
  fi
}


__INTERNAL_epelTemporarySkip() {
  rlLogDebug "$FUNCNAME(): try to access the repository to check availability"
  local cache="/var/tmp/beakerlib_library(distribution_epel)_skip"
  local res=1
  if [[ -r "$cache" ]]; then
    rlLogDebug "$FUNCNAME(): using cached state in $cache"
    res=0
  elif [[ "$1" == "set" && "$DIST" == "rhel" && "$REL" == "9" && $(date +%s) -lt $(date -d '2021-06-01' +%s) ]]; then
    rlLogDebug "$FUNCNAME(): caching the state in $cache"
    touch "$cache"
    res=0
  fi
  [[ $res -eq 0 ]] && {
    rlLogWarning "ignoring unavailable epel repo for RHEL-9 until 2021-06-01"
    rlLogInfo "    extend this date if necessary until the epel9 repo is ready"
  }
  return $res
}


# epelLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
epelLibraryLoaded() {
  rlImport distribution/epel-internal
  __INTERNAL_epelIsAvailable=''
  __INTERNAL_epelTemporarySkip && return 0
  #yum repolist all 2>/dev/null | grep -q epel && {
  __INTERNAL_epelRepoFiles && {
    rlLog "epel repo already present"
    return 0
  }
  local archive_used res epel_url i j u  epel
  local rel=`cat /etc/redhat-release` REL DIST DIST_LIKE
  if [[ -s /etc/os-release ]]; then
    DIST=$(. /etc/os-release; echo "$ID")
    DIST_LIKE=$(. /etc/os-release; echo "$ID_LIKE")
    REL=$(. /etc/os-release; echo "$VERSION_ID" | grep -o '[0-9]\+' | head -n 1)
  else
    echo "$rel" | grep -q 'Fedora' && DIST='fedora'
    echo "$rel" | grep -q 'Enterprise' && DIST='rhel'
  fi
  rlLog "Determined distro is '$DIST'"
  [[ "$DIST" == "fedora" ]] && return 0
  [[ "$DIST" == "rhel" || "$DIST_LIKE" =~ "rhel" ]] || {
    rlFail "unsupported distro"
    return 4
  }
  [[ -z "$REL" ]] && REL=`echo "$rel" | grep -o '[0-9]\+' | head -n 1`
  rlLog "Determined $DIST release is '$REL'"
  [[ -z "$REL" ]] && {
    rlFail "cannot determine release"
    return 5
  }
  [[ "$REL" =~ ^[0-9]+$ ]] || {
    rlFail "wrong release format"
    return 6
  }
  if rlIsRHEL '>=6.8'; then
    PROTO='https'
  else
    # Since dl.fedoraproject.org dropped TLS <1.2 support,
    # older RHELs cannot use NSS to connect to it over HTTPS anymore.
    PROTO='http'
  fi
  for j in 1 2 3; do
    case $j in
    1)
      rlIsRHEL 5 && continue
      epel_url="$PROTO://dl.fedoraproject.org/pub/epel"
      epel="epel-release-latest-$REL.noarch.rpm"
      archive_used=''
      res=0
      ;;
    2)
      epel_url="$PROTO://dl.fedoraproject.org/pub/archive/epel"
      epel="epel-release-latest-$REL.noarch.rpm"
      archive_used=1
      res=0
      ;;
    3)
      archive_used=''
      PARCH="x86_64"
      rlLog "find current epel-release package version"
      local webpage debug_stack i
      for i in 1 2 3; do
        rlLog "attempt no. $i"
        for epel_url in \
          "http://dl.fedoraproject.org/pub/epel/$REL/$PARCH/e" \
          "http://dl.fedoraproject.org/pub/epel/$REL/$PARCH" \
          "http://dl.fedoraproject.org/pub/epel/beta/$REL/$PARCH/e" \
          "http://dl.fedoraproject.org/pub/epel/beta/$REL/$PARCH" \
          "http://dl.fedoraproject.org/pub/archive/epel/$REL/$PARCH/e" \
          "http://dl.fedoraproject.org/pub/archive/epel/$REL/$PARCH" \
          ; do
          rlLog "using URL $epel_url"
          rlLogDebug "epel: executing '$__INTERNAL_epel_curl - "${epel_url}"'"
          webpage="$($__INTERNAL_epel_curl - "${epel_url}" 2>/dev/null)"
          rlLogDebug "epel: webpage='$webpage'"
          epel=$(echo "$webpage" | grep -Pom1 'epel-release.*?rpm' | head -n 1)
          debug_stack="$debug_stack
========================================= webpage $epel_url =========================================
$webpage
-------------------------------------------- epel $epel ---------------------------------------------
$epel
"
          rlLogDebug "epel: epel='$epel'"
          [[ -n "$epel" ]] && break 2
        done
      done
      ;;
    esac
    [[ -z "$epel" ]] && {
      rlLogError "could not find epel-release package"
      echo "$debug_stack
=====================================================================================================
"
      res=1
      continue
    }
    rlLog "found candidate source of '$epel', using url ${epel_url}/${epel}"
    rlLog "install epel repo"
    local epel_rpm
    if rlIsRHEL 5; then
      epel_rpm="$(mktemp -u -t epel_release_XXXXXXXX).rpm"
    else
      epel_rpm="$(mktemp -u --tmpdir epel_release_XXXXXXXX).rpm"
    fi
    rlLog "$__INTERNAL_epel_curl \"$epel_rpm\" \"${epel_url}/${epel}\""
    if $__INTERNAL_epel_curl "$epel_rpm" "${epel_url}/${epel}"; then
      res=0
      break
    else
      rlLogError "could not download epel-release package"
      res=2
      continue
    fi
  done
  [[ $res -ne 0 ]] && {
    __INTERNAL_epelTemporarySkip set && return 0
    return $res
  }
  rlRun "rpm -i \"$epel_rpm\"" || {
    rlLogError "could not install epel-release package"
    return 3
  }
  rlRun "rm -f \"$epel_rpm\""
  __INTERNAL_epelRepoFiles
  epelDisableRepos
  rlLog "setting skip if unavailable"
  for i in $epelRepoFiles ; do
    rlLogDebug "processing $i"
    rlLogDebug "  repo file before"
    rlLogDebug "$(cat $i)"
    sed -i '/^skip_if_unavailable=/d' "$i"
    sed -i 's/^enabled=.*/\0\nskip_if_unavailable=1/' "$i"
    [[ -n "$archive_used" ]] && sed -i 's|/pub/epel/|/pub/archive/epel/|' "$i"
    rlLogDebug "  repo file after"
    rlLogDebug "$(cat $i)"
  done
  return 0
}; # end of epelLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo 'done.'
