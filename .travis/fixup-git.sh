#!/bin/bash

set -e

DF_BEFORE_GIT="$(($(stat -f --format="%a*%S" .)))"

echo ""
echo ""
echo ""
echo "- Fetching non shallow to get git version"
echo "---------------------------------------------"
git fetch origin --unshallow || true
git fetch origin --tags

if [ z"$TRAVIS_PULL_REQUEST_SLUG" != z ]; then
	echo ""
	echo ""
	echo ""
	echo "- Fetching from pull request source"
	echo "---------------------------------------------"
	git remote add source https://github.com/$TRAVIS_PULL_REQUEST_SLUG.git
	git fetch source && git fetch --tags

	echo ""
	echo ""
	echo ""
	echo "- Fetching the actual pull request"
	echo "---------------------------------------------"
	git fetch origin pull/$TRAVIS_PULL_REQUEST/head:pull-$TRAVIS_PULL_REQUEST-head
	git fetch origin pull/$TRAVIS_PULL_REQUEST/merge:pull-$TRAVIS_PULL_REQUEST-merge
	echo "---------------------------------------------"
	git log -n 5 --graph pull-$TRAVIS_PULL_REQUEST-head
	echo "---------------------------------------------"
	git log -n 5 --graph pull-$TRAVIS_PULL_REQUEST-merge
	echo "---------------------------------------------"

	GITHUB_CURRENT_MERGE_SHA1="$(git log --pretty=format:'%H' -n 1 pull-$TRAVIS_PULL_REQUEST-merge)"
	if [ "$GITHUB_CURRENT_MERGE_SHA1" != "$TRAVIS_COMMIT" ]; then
		echo ""
		echo ""
		echo ""
		echo "- Pull request triggered for $TRAVIS_COMMIT but now at $GITHUB_CURRENT_MERGE_SHA1"
		echo ""
		echo "  SKIPPING!"
		echo ""
		exit 1
	fi

	echo ""
	echo ""
	echo ""
	echo "- Using pull request version of submodules (if they exist)"
	echo "---------------------------------------------"
	git submodule status | while read SHA1 MODULE_PATH
	do
		"$PWD/.travis/add-local-submodule.sh" "$TRAVIS_PULL_REQUEST_SLUG" "$MODULE_PATH"
	done
	echo "---------------------------------------------"
	git submodule foreach --recursive 'git remote -v; echo'
	echo "---------------------------------------------"
fi

if [ z"$TRAVIS_REPO_SLUG" != z ]; then
	echo ""
	echo ""
	echo ""
	echo "- Using local version of submodules (if they exist)"
	echo "---------------------------------------------"
	git submodule status | while read SHA1 MODULE_PATH DESC
	do
		"$PWD/.travis/add-local-submodule.sh" "$TRAVIS_REPO_SLUG" "$MODULE_PATH"
	done
	echo "---------------------------------------------"
	git submodule foreach --recursive 'git remote -v; echo'
	echo "---------------------------------------------"
fi

echo "---------------------------------------------"
git show-ref
echo "---------------------------------------------"

if [ z"$TRAVIS_BRANCH" != z ]; then
	TRAVIS_COMMIT_ACTUAL=$(git log --pretty=format:'%H' -n 1)
	echo ""
	echo ""
	echo ""
	echo "Fixing detached head (current $TRAVIS_COMMIT_ACTUAL -> $TRAVIS_COMMIT)"
	echo "---------------------------------------------"
	git log -n 5 --graph
	echo "---------------------------------------------"
	git fetch origin $TRAVIS_COMMIT
	git branch -v
	echo "---------------------------------------------"
	git log -n 5 --graph
	echo "---------------------------------------------"
	git branch -D $TRAVIS_BRANCH || true
	git checkout $TRAVIS_COMMIT -b $TRAVIS_BRANCH
	git branch -v
fi
echo ""
echo ""
echo ""
echo "Git Revision"
echo "---------------------------------------------"
git status
echo "---------------------------------------------"
git describe
echo "============================================="
GIT_REVISION=$(git describe)

echo ""
echo ""
echo ""
echo "- Disk space free (after fixing git)"
echo "---------------------------------------------"
df -h
echo ""
DF_AFTER_GIT="$(($(stat -f --format="%a*%S" .)))"
awk "BEGIN {printf \"Git is using %.2f megabytes\n\",($DF_BEFORE_GIT-$DF_AFTER_GIT)/1024/1024}"
