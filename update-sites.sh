#!/bin/bash

# Bail on errors
set +ex

# Stash org UUID
ORG_UUID=""

# Updated site URLs
PANTHEON_SITE_URLS=""

# Wraith failures
WRAITH_FAILURES="Review the following Wraith failures:\n"

# Stash list of all Pantheon sites in the org
# Uses the terminus org:site:list command to get a list of all sites in the org
# Could also use the terminus site:list command to get a list of all sites the user has access to, etc.
PANTHEON_SITES="$(terminus org:site:list -n ${ORG_UUID} --format=list --field=Name)"

# Loop through each site in the list
for PANTHEON_SITE_NAME in $PANTHEON_SITES; do
    # Check if the site is frozen
    IS_FROZEN="$(terminus site:info $PANTHEON_SITE_NAME --field=frozen)"

    # If the site is frozen
    if [[ "1" == "${IS_FROZEN}" ]]
    then
        # Then skip it
        echo -e "Skipping update of the site '$PANTHEON_SITE_NAME' because it is frozen...\n"
    else
        echo -e "\nKicking off an update check for ${PANTHEON_SITE_NAME}..."

        # check for upstream updates
        echo -e "\nChecking for upstream updates on ${PANTHEON_SITE_NAME}..."
        # the output goes to stderr, not stdout
        UPSTREAM_UPDATES="$(terminus upstream:updates:list ${PANTHEON_SITE_NAME}.dev  --format=list  2>&1)"

        UPDATES_APPLIED=false

        if [[ ${UPSTREAM_UPDATES} == *"no available updates"* ]]
        then
            # no upstream updates available
            echo -e "\nNo upstream updates found for ${PANTHEON_SITE_NAME}..."
        else
            # apply upstream updates
            echo -e "\nApplying upstream updates to ${PANTHEON_SITE_NAME}..."
            terminus upstream:updates:apply ${PANTHEON_SITE_NAME}.dev --yes --updatedb --accept-upstream
            UPDATES_APPLIED=true
        fi

        # Update local copy of the site
        echo -e "\nUpdating local copy of ${PANTHEON_SITE_NAME}..."

        cd ~/Projects/${PANTHEON_SITE_NAME}
        git pull --no-edit origin master

        fin start
        
        # Have composer stash any modified files in progress before updating and attempt to re-apply mods afterwards
        fin config set COMPOSER_DISCARD_CHANGES=stash
        fin composer --no-interaction update -W

        fin drush updb -y
        fin stop

        git add -A .
        git commit -m "Core & Contrib updates via DFM system."
        # Push the site to Pantheon 
        echo -e "\nPushing updates to ${PANTHEON_SITE_NAME} on Pantheon Dev..."
        git remote | xargs -L1 git push --all

        # Wait for the site to be updated on Pantheon
        echo -e "\nWaiting for ${PANTHEON_SITE_NAME} code to be updated on Pantheon Dev..."
        sleep 180

        # Update database on Pantheon Dev
        echo -e "\nUpdating database on ${PANTHEON_SITE_NAME} on Pantheon Dev..."
        terminus drush -n ${PANTHEON_SITE_NAME}.dev updb

        # Deploy the site to Pantheon Test
        echo -e "\nDeploying ${PANTHEON_SITE_NAME} to Pantheon Test..."
        terminus env:deploy -n --updatedb --sync-content --note="Core & Contrib updates." ${PANTHEON_SITE_NAME}.test

        # Clear the cache on Pantheon Test
        echo -e "\nClearing the cache on Pantheon Test..."
        terminus -n drush ${PANTHEON_SITE_NAME}.test cr

        # Add the site to the list of updated sites
        PANTHEON_SITE_URLS+="https://test-${PANTHEON_SITE_NAME}.pantheonsite.io/\n"

        # Wait for the site to be updated on Pantheon
        echo -e "\nWaiting for ${PANTHEON_SITE_NAME} code to be ready on Pantheon Test for VRT..."
        sleep 30

        # Run Wraith tests
        echo -e "\nRunning Wraith tests for ${PANTHEON_SITE_NAME} on Pantheon Test vs. LIVE..."
        WRAITH_TEST="$(wraith capture wraith/configs/capture.yaml  2>&1)"

        # Add the Wraith test results to the commit
        git add -A .
        git commit -m "Wraith test results from last TEST deployment."
        git remote | xargs -L1 git push --all

        # IF there is a failure in the Wraith test then add the site to the list of sites to review
        if [[ ${WRAITH_TEST} == *"Failure"* ]]
        then
          echo -e "\nWraith test failed for ${PANTHEON_SITE_NAME} TEST, so it will need review before deployment to LIVE."
          WRAITH_FAILURES+="file://${HOME}/Projects/${PANTHEON_SITE_NAME}/wraith/shots/gallery.html :  https://test-${PANTHEON_SITE_NAME}.pantheonsite.io/ vs. https://live-${PANTHEON_SITE_NAME}.pantheonsite.io/\n"
        else
          # Deploy the site to Pantheon Live
          echo -e "\nWraith tests passed!  Deploying ${PANTHEON_SITE_NAME} to Pantheon Live..."
          terminus env:deploy -n --updatedb --note="Core & Contrib updates." ${PANTHEON_SITE_NAME}.live
        fi
    fi
done

echo -e "\n\nDone updating the following sites:\n${PANTHEON_SITES}\n"
echo -e "\n\nReview the following sites:\n${PANTHEON_SITE_URLS}\n"
echo -e "\n\n${WRAITH_FAILURES}\n"

echo -e "\n\nAfter resolving failures, deploy all remaining sites with:\n"
echo "terminus org:site:list -n ${ORG_UUID} --format=list --field=Name | xargs -L1 -I{} terminus env:deploy -n --updatedb --cc --note='Core & Contrib updates.' {}.live"
echo -e "\n\n"
