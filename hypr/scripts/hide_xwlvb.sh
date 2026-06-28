#!/bin/bash
echo "start DISPLAY=$DISPLAY $(date)" > /tmp/xwlvb.log
sleep 5
while true; do
    xdotool search --classname xwaylandvideobridge windowunmap >> /tmp/xwlvb.log 2>&1 && echo "unmapped $(date)" >> /tmp/xwlvb.log
    sleep 2
done
