#!/usr/bin/env bash

DATE=$(date +%Y-%m-%d)
if [ -f /etc/os-release ]; then
  PRETTY_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
else
  PRETTY_NAME="Unknown"
fi

sudo snap refresh core --stable
snapd_version=$(snap version | grep snapd | sed 's/snapd   //' | sed 's/ //g')
snapd_core=$(snap info core | grep stable: | cut -d'-' -f2 | cut -d'(' -f1 | sed 's/ //g')
sudo snap refresh core --beta
sudo snap install hello-world

GOOD=$(snap run hello-world > /dev/null 2>&1)
if [ $? -eq 0 ]; then
  GOOD_WORKS="️️✔️"
else
  GOOD_WORKS="❌"
fi
echo "Snaps work:          ${GOOD_WORKS}"

EVIL=$(snap run hello-world.evil > /dev/null 2>&1)
if [ $? -ne 0 ]; then
  EVIL_WORKS="✔️"
else
  EVIL_WORKS="❌"
fi
echo "Snap confinement:    ${EVIL_WORKS}"

XDG=$(xdg-open snap://hello-world > /dev/null 2>&1)
if [ $? -eq 0 ]; then
  XDG_WORKS="✔️"
else
  XDG_WORKS="❌"
fi
echo "snap:// handler:     ${XDG_WORKS}"


snapd_beta_version=$(snap version | grep snapd | sed 's/snapd   //' | sed 's/ //g')
snapd_beta_core=$(snap info core | grep beta: | cut -d'-' -f2 | cut -d'(' -f1 | sed 's/ //g')
if [ "$snapd_beta_version" = "$snapd_beta_core" ]; then
  REEXEC="✔️"
else
  REEXEC="❌"
fi
echo "Snap re-exec:        ${REEXEC}"
echo "Snap stable version: $snapd_version"
echo "Snap stable core:    $snapd_core"
echo "Snap beta version:   $snapd_beta_version"
echo "Snap beta core:      $snapd_beta_core"

echo
echo -e "Date Checked\tDistro\tcurrent snapd\tre-exec capable\thello-world\thello-world.evil\tSupports snap://"
echo -e "${DATE}\t${PRETTY_NAME}\t${snapd_version}\t${REEXEC}\t${GOOD_WORKS}\t${EVIL_WORKS}\t${XDG_WORKS}"
echo
