@echo off
echo Starting TFS Server via WSL...
wsl -e bash -c "cp /mnt/c/otcv8-dev-master/otserv/build/tfs /mnt/c/otcv8-dev-master/otserv/tfs && cd /mnt/c/otcv8-dev-master/otserv && ./tfs"
pause
