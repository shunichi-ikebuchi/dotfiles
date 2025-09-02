#!/bin/bash

# This script executes various defaults commands on macOS to customize the system.
# Comments are added to each section, and killall commands are included to apply changes.
# Please check the contents before execution.

echo "Starting macOS defaults customization."

# Finder related settings
echo "Applying Finder settings..."
defaults write com.apple.finder AppleShowAllFiles -bool true          # Always show hidden files in Finder
defaults write com.apple.finder AppleShowAllExtensions -bool true     # Show all file extensions in Finder
defaults write com.apple.finder ShowPathbar -bool true                # Show path bar at the bottom of Finder windows
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true    # Display full POSIX path as Finder window title
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false  # Disable the warning when changing a file extension
defaults write com.apple.finder ShowStatusBar -bool true              # Show status bar in Finder
killall Finder                                                        # Restart Finder to apply changes

# Screenshot related settings
echo "Applying Screenshot settings..."
mkdir -p ~/Documents/Screenshots                                         # Create a directory for screenshots if it doesn't exist
defaults write com.apple.screencapture location ~/Documents/Screenshots  # Change screenshot save location to ~/Documents/Screenshots
defaults write com.apple.screencapture type jpg                       # Change screenshot format to JPG
killall SystemUIServer                                                # Restart SystemUIServer to apply changes

# VSCode related settings (for Vimmers)
echo "Applying VSCode settings..."
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false  # Disable press-and-hold for keys in VSCode (enables key repeat)

# Miscellaneous settings
echo "Applying miscellaneous settings..."
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true  # Avoid creating .DS_Store files on network volumes
defaults write com.apple.dock appswitcher-all-displays                # Show app switcher on all displays (value might need -bool true or similar; check defaults)

echo "All customizations are complete. Restart if necessary."