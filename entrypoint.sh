#!/bin/bash -l
set -euo pipefail

file_name=$1
tag_version=$2
if [[ "$tag_version" == "true" ]]; then
  echo "Tagging this release when run complete"
else
  echo "Will NOT be tag this run"
fi
echo "Treating branch ${GITHUB_BASE_REF} as HEAD"

echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Ref: ${GITHUB_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"

echo "Starting Git Operations"
git config --global user.email "Bump-N-Tag@github-action.com"
git config --global user.name "Bump-N-Tag App"

github_ref=""
if test "${GITHUB_EVENT_NAME}" = "push"
then
    github_ref=${GITHUB_REF}
else
    github_ref=${GITHUB_HEAD_REF}
    git fetch origin ${GITHUB_HEAD_REF}
fi

echo "Git Checkout"

git fetch origin ${GITHUB_BASE_REF}
git checkout $github_ref

if test -f $file_name; then
    content=$(cat $file_name)
else
    content=$(echo "-- File doesn't exist --")
    echo "Could not find file at path ${file_name}"
    exit 1
fi

echo "File Content: $content"
extract_string=$(echo $content | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,3})(\.([0-9]{1,5}))?[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then 
    echo "Invalid version string"
    exit 1
else
    echo "Valid version string found"
fi

major=$(echo $extract_string | cut -d'.' -f1) 
major=${major:(-1)}
minor=$(echo $extract_string | cut -d'.' -f2)
patch=$(echo $extract_string | cut -d'.' -f3)
build=$(echo $extract_string | cut -d'.' -f4)

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

# TODO: Compare against HEAD branch to see if $file_name has been updated there
# and if so, bump our revision to one more than what is on HEAD

if [[ "$file_name" == "./"* ]]; then 
  file_name="${file_name:2}"
fi

if [[ "$github_ref" != "" ]]; then 
  version_file_updated=`git diff --name-only origin/${GITHUB_BASE_REF}..HEAD $github_ref | grep $file_name | wc -l`
  if [[ $version_file_updated -ge 1 ]]; then
    echo "Version File Already Updated"
    exit 0
  fi

  git add -A 
  git commit -m "Incremented to ${newver}"
  ([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${newver}" -m "${GITHUB_REPOSITORY} Release") || echo "No tag created"

  git show-ref
  echo "Git Push"

  git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:$github_ref
fi

echo "End of Action"
exit 0
