#!/usr/bin/env bash
# install.sh: copy run.sh to /usr/local/bin/qode
if [ -f "./run.sh" ]; then
  sudo cp "./run.sh" /usr/local/bin/qode
  sudo chmod +x /usr/local/bin/qode
  echo "Copied run.sh to /usr/local/bin/qode"
else
  echo "run.sh not found, skipping copy."
fi
