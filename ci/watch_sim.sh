#!/bin/bash
# Roda a versão de demonstração do app do relógio no simulador e tira capturas de cada tela.
cd /app/watch
apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq imagemagick x11-apps xdotool >/dev/null 2>&1
mkdir -p /app/shots
monkeyc -f demo.jungle -d fr245m -o /tmp/demo.prg -y /app/ci/garmin_dev_key.der -l 0 2>&1 | tail -5
export DISPLAY=:1
Xvfb :1 -screen 0 1280x1024x24 >/dev/null 2>&1 &
sleep 2
simulator >/dev/null 2>&1 &
sleep 8
monkeydo /tmp/demo.prg fr245m > /app/shots/log.txt 2>&1 &
sleep 2.5
for i in $(seq -w 0 13); do
  xdotool key Return 2>/dev/null; sleep 0.3; import -window root /app/shots/s$i.png 2>/dev/null
  sleep 3
done
sleep 1
echo "---- log do simulador ----"; cat /app/shots/log.txt
