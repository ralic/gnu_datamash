#!/bin/sh

## Copyright (C) 2014-2017 Assaf Gordon <assafgordon@gmail.com>
##
## This file is part of GNU Datamash.
##
## GNU Datamash is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## GNU Datamash is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with GNU Datamash.  If not, see <http://www.gnu.org/licenses/>.


die()
{
BASE=$(basename "$0")
echo "$BASE: error: $@" >&2
exit 1
}

dict_set()
{
  key=$1
  value=$2
  eval "__data__$key=\"$value\""
}

dict_get()
{
  key=$1
  eval "echo \$__data__$key"
}

## parse parameterse
show_help=
pass_params=
while getopts b:c:m:e:h name
do
        case $name in
        b|c|m|e) pass_params="$pass_params -$name '$OPTARG'"
                 ;;
        h)       show_help=y
                 ;;
        ?)       die "Try -h for help."
        esac
done
[ ! -z "$show_help" ] && show_help_and_exit;

shift $((OPTIND-1))

## First non-option parameter: the source to build
SOURCE=$1
[ -z "$SOURCE" ] &&
  die "missing SOURCE file name / URL (e.g. datamash-1.0.1.tar.gz)"
shift 1

## Any remaining non-option parameters: hosts
if [ $# -eq 0 ] ; then
  # No hosts given - use default list
  HOSTS="deb7 deb7clang deb732 deb732clang centos65 centos5 fbsd10
fbsd93 fbsd84 netbsd614 dilos dilos64 hurd obsd"
else
  HOSTS="$@"
fi

LOGDIR=$(mktemp -d -t buildlog.XXXXXX) ||
  die "Failed to create build log directory"

##
## Start build on all hosts
##
ALLLOGFILES=""
for host in $HOSTS ;
do
    LOGFILE=$LOGDIR/$host.log
    echo "Starting remote build on $host (log = $LOGFILE ) ..."
    ./build-aux/check-remote-make.sh \
        $pass_params \
        "$SOURCE" "$host" 1>$LOGFILE 2>&1 &
    pid=$!
    dict_set $host $pid
    ALLLOGFILES="$ALLLOGFILES $LOGFILE"
done

echo "Waiting for remote builds to complete..."
echo "To monitor build progress, run:"
echo "   tail -f $ALLLOGFILES"
echo ""


##
## For completion, report result
##
for host in $HOSTS ;
do
    LOGFILE=$LOGDIR/$host.log
    pid=$(dict_get $host)
    wait $pid
    exitcode=$?
    if [ "$exitcode" -eq "0" ]; then
        echo "$SOURCE on $host - build OK"
    else
        echo "$SOURCE on $host - Error (log = $LOGFILE )"
    fi
done
