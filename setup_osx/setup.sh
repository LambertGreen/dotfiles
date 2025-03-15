#!/usr/bin/env sh

lgreen_setup_finder() {
    defaults write com.apple.finder AppleShowAllFiles TRUE
}

lgreen_setup_reset_tcc_database() {
    tccutil reset Accessibility
}

lgreen_setup_disable_os_scroll_inversion() {
    defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
}
