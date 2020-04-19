#!/bin/bash
# Copyright (c) 2020 Shane "Dataforce" Mc Cormack
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

########################################
# Global Config
########################################
# Name of file to look for repo config in
CONFIGFILE="CONFIG"

# Name of directory to store logs in
LOGDIR="logs"

# Name of directory to store git checkout in
CHECKOUTDIR="checkout"

# Prefix used for tags when building repo
TAGPREFIX="builder"

# Location where we look for repos to build. Blank for the dir the script is in
BASEDIR=""

########################################
# BEGIN
########################################
if [ "" = "${BASEDIR}" ]; then
	SCRIPT=`readlink -f "${0}"`
	BASEDIR=$(dirname "${SCRIPT}")
fi;
cd ${BASEDIR};

# Lock file to ensure we only run one instance of this script at a time.
LOCKFILE="${BASEDIR}/.runlock"

# What time did we start at - to ensure all log files have the same file name.
RUNTIME=$(date '+%F-%T%z.%s')

(
	flock -x -n 200
	if [ ${?} -ne 0 ]; then
		echo "Script already running, aborting."
		exit 1;
	fi;

	# Look for repos in our base directory
	for REPONAME in `ls "${BASEDIR}"`; do
		# Only care abour directories that have a config file.
		if [ -d "${REPONAME}" -a -e "${BASEDIR}/${REPONAME}/${CONFIGFILE}" ]; then
			THISDIR="${BASEDIR}/${REPONAME}"
			cd ${THISDIR}

			# Ensure we have somewhere to log to
			if [ ! -e "${LOGDIR}" ]; then
				mkdir ${LOGDIR}
			fi;

			# Logfile for logging output
			LOGFILE="${THISDIR}/${LOGDIR}/${RUNTIME}.log"

			# Start a new subshell for building to ensure config vars don't leak between builds.
			(
				# Include the config
				source "./${CONFIGFILE}"

				# Exit this subshell if there is no url.
				if [ "" = "${URL}" ]; then
					exit 1;
				fi;

				# Checkout the latest version of the repo.
				if [ ! -d "${CHECKOUTDIR}" ]; then
					# Clone if there is no repo
					git clone "${URL}" ${CHECKOUTDIR}
					if [ $? != 0 ]; then
						rm -Rf ${CHECKOUTDIR}
						echo "Bad clone url."
						exit 1;
					fi;

					cd ${CHECKOUTDIR}
					if [ "" != "${BRANCH}" ]; then
						git checkout "${BRANCH}"
					fi;
					OLDHASH=""
				else
					# If there is a previous checkout, bring it up to date.
					cd ${CHECKOUTDIR}
					OLDHASH=$(git rev-parse HEAD)

					git reset --hard
					git pull
				fi;

				# What is the current commit of the repo now?
				NEWHASH=$(git rev-parse HEAD)

				# If the new hash is not the same as the old one then we need to build.
				if [ "${NEWHASH}" != "${OLDHASH}" ]; then
					# New subshell for ease-of-logging.
					(
						echo '========================================';
						echo 'Hash changed from "'${OLDHASH}'" to "'${NEWHASH}'" - triggering builds.';
						echo '========================================';

						# If BUILDS isn't specified, then use a default.
						if [ "${BUILDS}" = "" ]; then
							BUILDS=(REPO)
						fi;

						# We may need to build multiple things, so loop through BUILDS.
						for B in "${BUILDS[@]}"; do
							if [ "${B}" = "" ]; then
								continue;
							fi;

							# Get the name of the dockerfile to use for this build.
							DOCKERFILE='DOCKERFILE_'${B}
							DOCKERFILE=${!DOCKERFILE}
							if [ "${DOCKERFILE}" = "" ]; then DOCKERFILE="Dockerfile"; fi;

							# Build path to use for this build.
							BUILDPATH='BUILDPATH_'${B}
							BUILDPATH=${!BUILDPATH}
							if [ "${BUILDPATH}" = "" ]; then BUILDPATH="."; fi;

							# Push Targets for this Build.
							TARGETS='TARGETS_'${B}
							TARGETS=${!TARGETS}

							# If the dockerfile exists, then we can build
							if [ -e "${DOCKERFILE}" ]; then
								# Known build tag so that we can then push this after it has built.
								BUILDTAG=$(echo "${TAGPREFIX}/${REPONAME}/${B}:${NEWHASH}" | tr '[:upper:]' '[:lower:]')

								echo '========================================';
								echo 'Building "'${B}'" in "'${BUILDPATH}'" using "'${DOCKERFILE}'" as "'${BUILDTAG}'"'
								echo '========================================';

								# Finally, actually build.
								docker build -f "${DOCKERFILE}" -t "${BUILDTAG}" "${BUILDPATH}"

								# Once built, push to all the push targets
								if [ $? -eq 0 -a "${TARGETS}" != "" ]; then
									for T in "${TARGETS[@]}"; do
										if [ "${T}" = "" ]; then
											continue;
										fi;
										echo '===================='
										echo 'Pushing to "'${T}'"'
										echo '===================='

										docker tag "${BUILDTAG}" "${T}"
										docker push "${T}"
									done;
								fi;
							fi;
						done;
					) 2>&1 | tee ${LOGFILE}
				fi;
			)
		fi;
	done;
) 200>${LOCKFILE}
