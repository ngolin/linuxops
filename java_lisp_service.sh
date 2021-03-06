#!/usr/bin/env bash
python <<EOF
from __future__ import print_function
for l, i in enumerate(range(0, ${COLUMNS:-80} // 2, ${COLUMNS:-80} % 2 + 2)):
  if l % 2:
    print(' ' * i, end='')
  print('*' * (${COLUMNS:-80} - i))
EOF


if [ -z "$BASH" ]; then
  echo 'Oops, expect `bash`.'.
  exit 1
fi


if [[ $EUID -ne 0 ]]; then
  echo 'Oops, expect `root` user or `sudo`.'.
  exit 1
fi


if [[ -z $JAVA_HOME ]]; then
  if which java &>/dev/null; then
    JAVA_HOME=$(dirname $(dirname $(realpath $(which java))))
  else
    echo 'Oops, expect `$JAVA_HOME`.'
    printf '\n  Try `sudo -E` to preserve environment.\n\n'
    exit 1
  fi
fi


if ! $JAVA_HOME/bin/java -version &>/dev/null; then
  echo 'Oops, expect `$JAVA_HOME/bin/java`.'
  exit 1
fi


servefor() {

  app_name=$(basename $1)
  ser_name=$(sed -e 's/-[.0-9]*$//g' <<<$app_name)

  if [[ $app_name != lisp-* ]]; then
    echo Oops, expect $app_name starting with '`lisp-`'.
    exit 1
  fi

  if [[ ! -d $1/lib ]] || [[ ! -f $1/app.jar ]]; then
    echo 'Oops, expect `lib/` and `app.jar` in' $app_name.
    exit 1
  fi

  if systemctl status $ser_name &>/dev/null; then
    printf '\n\n`%s` is running, stopping...\n\n\n' $ser_name
    systemctl stop $ser_name
  fi

  printf '\nWritting `%s`...\n\n' /etc/systemd/system/$ser_name.service

  lines=(
    "[Unit]"
    "Description=Manage Java \`$app_name\` service"
    "After=network.target"
    ""
    "[Service]"
    "WorkingDirectory=$1"
    "ExecStart=$JAVA_HOME/bin/java -Djava.ext.dirs=./lib:$JAVA_HOME/jre/lib/ext -server -Xms512m -Xmx1024m -Xss512k -XX:MetaspaceSize=64m -XX:MaxMetaspaceSize=128m -XX:MaxNewSize=64m -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -jar app.jar"
    "Restart=on-failure"
    "RestartSec=10"
    ""
    "[Install]"
    "WantedBy=multi-user.target"
  )

  printf '%s\n' "${lines[@]}" >/etc/systemd/system/$ser_name.service

  systemctl daemon-reload

  if systemctl start $ser_name; then
    systemctl --no-pager status $ser_name
    if ! systemctl is-enabled $ser_name &>/dev/null; then
      systemctl enable $ser_name
    fi
  fi
  
}


if [[ $# == 0 ]]; then
  servefor $PWD
else
  for name; do
    if cd "$name" &>/dev/null; then
      servefor $PWD; cd $OLDPWD
    else
      printf '\nNo such directory: `%s`\n\n' $name
    fi
  done
fi
