#!/bin/sh -l
set -euox pipefail

file_name=$1
tag_version=$2
echo "Input file name: $file_name : $tag_version"

echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"

echo "Starting Git Operations"
git config --global user.email "Bump-N-Tag@github-action.com"
git config --global user.name "Bump-N-Tag App"

github_ref=""

git fetch

if test "${GITHUB_EVENT_NAME}" = "push"
then
    github_ref=${GITHUB_REF}
else
    github_ref=${GITHUB_HEAD_REF}
    git checkout $github_ref
fi


echo "Git Checkout"

if test -f $file_name; then
    content=$(cat $file_name)
else
    content=$(echo "-- File doesn't exist --")
fi

echo "File Content: $content"
extract_string=$(echo $content | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,3})(\.([0-9]{1,5}))?[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then 
    echo "Invalid version string"
    exit 0
else
    echo "Valid version string found"
fi

major=$(echo $extract_string | cut -d'.' -f1) 
major=${major:(-1)}
minor=$(echo $extract_string | cut -d'.' -f2)
patch=$(echo $extract_string | cut -d'.' -f3)
build=$(echo $extract_string | cut -d'.' -f4)

echo $major $minor $patch $build

if [[ "$build" == "" ]]; then
    oldver=$(echo $major.$minor.$patch)
    patch=$(expr $patch + 1)
    newver=$(echo $major.$minor.$patch)
else
    oldver=$(echo $major.$minor.$patch.$build)
    build=$(expr $build + 1)
    newver=$(echo $major.$minor.$patch.$build)
fi

echo "Old Ver: $oldver"
echo "Updated version: $newver" 

newcontent=$(echo ${content/$oldver/$newver})
echo $newcontent > $file_name

git diff --name-only origin/stable..HEAD $github_ref

version_file_updated=`git diff --name-only origin/stable..HEAD $github_ref | grep $file_name | wc -l`
echo "version fiole updated: " $version_file_updated
if [[ $version_diff -ge 1 ]]; then
  echo "Version File Already Updated in this PR"
  exit 0
fi

git add -A 
git commit -m "Incremented to ${newver}"  -m "[skip ci]"
([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${newver}" -m "[skip ci]") || echo "No tag created"

git show-ref
echo "Git Push"

git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:$github_ref

echo "End of Action\n\n"
exit 0
