#!/bin/bash

trap 'abort' 0

set -e

trap : 0

########################################
## Functions
########################################

curl_success() {
  code=$(sed -n "s,.*HTTP/1.1 \([0-9]\{3\}\).*,\1,p" <<< "$1")
  [[ "$code" -eq "201" ]] || [ "$code" -eq "200" ]
}

parse_github_issue_number() {
  github_issue_number=$(sed -n "s,.*\"number\":[[:space:]]*\([0-9]*\).*,\1,p" <<< "$1")
}


########################################
## Echo
########################################


echo ""
echo "------------------------------------------------------------"
echo "  Math Library's develop branch updated"
echo "  Creating a pull request on Stan to update its submodule"
echo ""

########################################
## Create GitHub issue
########################################

math_commit_hash=$(cd lib/stan_math && git rev-parse --short origin/develop)
issue="{ 
  \"title\": \"Update submodule for the Stan Math Library\",
  \"body\":  \"The Stan Math Library develop branch has been updated.\nUpdate the submodule to ${math_commit_hash}.\" }"

response=$(eval curl --include --user \"$github_user:$github_token\" --request POST --data \'$issue\' https://api.github.com/repos/stan-dev/stan/issues)


if ! curl_success "${response}"; then
  _msg="
Error creating pull request:
----------------------------
$data


Response:
---------
$response
"
  exit 1
fi

parse_github_issue_number "${response}"


########################################
## Fix issue on a branch:
## - Create a git branch
## - Update the Math Library to develop
## - Commit and push
########################################
git checkout -b feature/issue-${github_issue_number}-update-math
make math-update/${math_commit_hash}
git commit -m "Fixes #${github_issue_number}. Updates the Math submodule to ${math_commit_hash}. [skip ci]" lib/stan_math
git push

########################################
## Crate pull request
########################################

pull_request="{
  \"title\": \"Update submodule for the Stan Math Library\",
  \"head\": \"feature/issue-${github_issue_number}-update-math\",
  \"base\": \"develop\",
  \"body\": \"#### Summary:\n\nUpdates the Math submodule to the current develop version, ${math_commit_hash}.\n\n#### Intended Effect:\n\nThe Stan Math Library \`develop\` branch has been updated.\nThis pull request updates the submodule for the Stan Math Library submodule to ${math_commit_hash}.\n\n#### Side Effects:\n\nNone.\n\n#### Documentation:\n\nNone.\n\n#### Reviewer Suggestions: \n\nNone.\" }"

response=$(eval curl --include --user \"$github_user:$github_token\" --request POST --data \'$pull_request\' https://api.github.com/repos/stan-dev/stan/pulls)

if ! curl_success "${response}"; then
  _msg="
Error creating pull request
----------------------------
$data


Response:
---------
$response
"

########################################
## Done
########################################

trap : 0 


echo "------------------------------------------------------------"
echo ""
echo "Success creating a pull request updating submodule"
echo ""
echo "------------------------------------------------------------"
echo ""

exit 0

