

# Uncomment below to see a greeting when loading your profile
export GREETING=1
[ $GREETING ] && echo "Welcome $(whoami), setting up your profile..."

[ -f ~/.profile ] && source ~/.profile

if [ $GREETING ]; then
    [ -x "$(command -v neofetch)" ] && neofetch
    echo "Profile setup complete. Happy coding."
fi
