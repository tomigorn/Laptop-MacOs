#!/bin/bash

# Add a small spacer to the Dock for grouping applications
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="small-spacer-tile";}'
killall Dock
