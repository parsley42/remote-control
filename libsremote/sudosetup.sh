chmod 0700 $SUDO_ASKPASS
chmod +x $SUDO_ASKPASS
cat >> $SUDO_ASKPASS <<<$RCSUDOPASS
unset RCSUDOPASS
# Test the password before going on
sudo -A /bin/true || { echo "sudo failed. Wrong password?"; exit 1; }
sudo -A su <<"RCSUDOSCRIPTEOF"
