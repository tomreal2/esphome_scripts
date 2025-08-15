#!/bin/sh
if ping -c 1 192.168.1.213 &> /dev/null
then
  sleep 10
	ffmpeg -rtsp_transport tcp -i rtsp://admin:Havea6and3@192.168.1.213:554/h264Preview_01_main -frames:v 1 /home/pi/blue/imgs/T/img-T-$(date +'%Y%m%d-%H%M%S').jpg
fi