#!/usr/bin/env bash
re='^[0-9]+$'
if ! [[ $1 =~ $re ]] ; then
   echo "error: usage 'generate-changelog.sh NUM URL_PREFIX' (NUM = number of versions to include, URL_PREFIX = URL prefix for opening commits)" >&2; exit 1
fi

generated_at=$(date +%d.%m.%Y)
printf "# Changelog\n"
printf "_Generated_ __${generated_at}__\n\n"

# Output version history
previous_tag=0
num_tags=$(($1+1))
for current_tag in $(git tag --sort=-creatordate | head -n $num_tags)
do
    if [ "$previous_tag" != 0 ];then
        tag_date=$(git log -1 --pretty=format:'%ad' --date=format:%d.%m.%Y ${previous_tag})
        printf "## ${previous_tag}\n"
        printf "**${tag_date}**\n\n"
        git log ${current_tag}...${previous_tag} --pretty=format:"*  **%an** %s [%h](${2}%H)" --reverse | grep -v Merge
        printf "\n\n"
    fi
    previous_tag=${current_tag}
done

# Output history from first commit to first version
if [ "$1" -ge "$(git tag --sort=-creatordate | wc -l)" ]
then
    first_commit=$(git rev-list --max-parents=0 HEAD)
    first_tag=$(git tag --sort=creatordate | head -n 1)
    first_date=$(git log -1 --pretty=format:'%ad' --date=short ${first_tag})
    printf "## $first_tag (${first_date})\n\n"
    git log ${first_commit} --pretty=format:"*  %s [Show commit](${2}%H)" --reverse | grep -v Merge
    git log ${first_commit}...${first_tag} --pretty=format:"*  **%an** %s [%h](${2}%H)" --reverse | grep -v Merge
    printf "\n\n"
fi
