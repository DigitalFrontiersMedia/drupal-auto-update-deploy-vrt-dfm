# Drupal Automatic Updates & Deployments
# with Visual Regression Testing
Scripts associated with setting up a Drupal automatic update and deployment process with Visual Regression Testing.  Useful for Pantheon users who do not have access to AutoPilot.

## Rundown
   - This process is geared toward Mac users.
   - The Mac’s Battery/Energy settings are set to power-on and/or wake computer a few minutes before your decided update time, e.g. 6:55am on Thursdays for a 7am update time.
   - An Apple Calendar repeating event is set, e.g. every Thursday at 7am.  This could have been done with a crontab, but those are deprecated and the new recommended method just seemed overly complex and I liked being able to see it listed in my Calendar along with the pop-up alert and ability to easily change the day using the Calendar UI.
   - Calendar pops up an alert at the specified date/time and runs an AppleScript.
   - The AppleScript opens iTerm2 if not already open, opens a new session window and executes a shell script.
   - The shell script retrieves a list of sites hosted on Pantheon.
   - It iterates through each site:
       - applies any upstream updates
       - fires up Docksal environment
       - pulls latest code from DEV
       - runs composer update
       - pushes code updates to DEV
       - deploys code updates to TEST with content backsync from LIVE and drush updatedb
       - runs a Wraith Visual Regression Test (VRT) between TEST and LIVE
       - deploys code updates to LIVE if VRT passes (adds site to list to review if not)
   - Provides list of sites that failed VRT with links to Wraith comparison screenshots and site links
   - Provides a one-liner to run once sites have been reviewed/fixed to deploy remaining site updates to LIVE

## TODO
   - Create PC equivalents for Calendar, AppleScript, possibly BASH portions (depending on client config)
   - Provide DDEV command equivalents for Docksal commands
   - Abstract the site list and deployment commands (currently done with terminus) so that one could port this to any hosting provider with a good API.
   - Potentially replace Wraith with a more modern VRT tool
   
## Assumptions
1. Using a Mac
2. Using Docksal as the local development environment on your sites

## Steps to Setup
1. Save the `update-sites.sh` file from this repo to /usr/local/bin or your desired shell executable path.  Make sure it has proper ownership and permissions to be executed by your computer user account.
2. Update the ORG_UUID value in line 7 of `update-sites.sh`.  Or update the terminus command on line 18 with the appropriate command to get the desired list of sites if Pantheon Organization won't work to get what you want.
3. Update the site projects path in line 54 of `update-sites.sh` if your sites are stored in a different parent directory. Also note that this process assumes each site directory is named after its site name in Pantheon.  So this might be something that needs adjusting for different setups.
4. Install Wraith (https://github.com/bbc/wraith).  Documentation & installation instructions location has changed; it is now located at (https://bbc.github.io/wraith/).
5. Create a `wraith` directory in your project root above docroot that includes `configs` and `shots` subdirectories.
6. Copy `capture.yaml`, `history.yaml`, and `spider_paths.yaml` from this repo to `wraith/configs` so you have a structure similiar to the following: ![Wraith setup.](https://github.com/DigitalFrontiersMedia/drupal-auto-update-deploy-vrt-dfm/blob/main/wraith-setup.png?raw=true)
7. The `wraith spider` command may not work on your machine to automatically get urls for Wraith to check.  This is due to an obsolete component used for that function that won't run with modern versions of Ruby.  Alternatively, you may simply manually update/enter the url paths to check that are listed in the provided `spider_paths.yaml` file (which is what would have been produced by the `wraith spider` command).
8. Update the `browser`, `domains`, `screen_widths`, `before_capture`, `fuzz`, `threshold`, and any other values in the `capture.yaml` and `history.yaml` files as appropriate for your use case.
9. Open Mac's Automator app and load the `updatesites.app` from this repo.  Edit the `updateTime` variable from "7" to the hour you wish updates to begin (24-hour format), e.g. 3:30pm would be 15.5.  Unfortunately, without setting the time here (even though you're also setting it with the Calendar event, itself), iTerm2 will run the script twice after a variable amount of time a few minutes to 15+ minutes later.  This time checks to make sure the script doesn't execute the commands if the time has surpassed the targeted minute.  ![updatesites.app.](https://github.com/DigitalFrontiersMedia/drupal-auto-update-deploy-vrt-dfm/blob/main/updatesites.png?raw=true)
10. Build the AppleScript in Automator (button with hammer icon) and then save it as a Calendar Alarm.  It defaulted to saving mine to `~/Library/Workflows/Applications/Calendar`; I don't know if it needs to be there, if it's just easier for Calendar to find it there, or if it can be somewhere easier to navigate to instead, so I suggest just putting it at that location unless you wish to experiment with that.
11. Open Calendar and create a recurring event named "Site Updates" for the day, time, and frequency you want the updates to run (the time should match the time entered in #9 above).  For the alarm setting, choose "Custom" and then "Open file" from the dropdown option it presents.  Choose "Other" from the next dropdown and then navigate to the AppleScript you saved in #10 above and select it.  Follow this by changing the third dropdown to "At time of event".  Then click "OK" to finish setting up the recurring event.  ![updatesites.app.](https://github.com/DigitalFrontiersMedia/drupal-auto-update-deploy-vrt-dfm/blob/main/recurring-event.png?raw=true)
12. Finally, (optionally) ensure that your computer will be on and awake so it will never miss an update.  Open Mac's "System Preferences" app and navigate to "Battery" (may be called "Energy" or something else on desktops instead of laptops).  Click the "Schedule" vertical tab on the left and set a "Start up or wake" day and time to be a few minutes before the day/time you set in #11 and #9.  NOTE:  Laptops will not startup/wake if the clamshell is closed.  ![updatesites.app.](https://github.com/DigitalFrontiersMedia/drupal-auto-update-deploy-vrt-dfm/blob/main/power-wakeup.png?raw=true)
13. Wait for the designated day/time and watch the sites update themselves.  NOTE:  The Calendar event may not alarm at the top of the minute; it may execute at anytime within that designated minute.

***You will want to make sure you have backups of all your sites prior to this executing.  You should also monitor this the first few times it runs.***  I had this set to run every Thursday at 7am for 10 client sites so that they were ready for review by the time I sat down around 9 to start work.  I actually prefer the Wraith VRT comparison interface to what is currently in Pantheon’s Autopilot (which just seems nearly impossible to spot small issues on, IMO).

You will also probably need to fiddle with some of the Wraith settings to prevent false failures yet not be so permissive as to miss actual small, but important, failures.  More on this is considered in this video, which gives an overview of the system:  https://digitalfrontiersmedia.com/sites/default/files/Drupal-Autoupdates-DFM.mp4
