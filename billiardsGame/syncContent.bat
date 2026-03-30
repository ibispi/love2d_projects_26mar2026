@echo off
..\rclone\rclone.exe sync ./content/ droplet:/home/game-assets/billiardsGame/content/ --progress
pause