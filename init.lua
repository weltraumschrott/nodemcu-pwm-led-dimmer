--[[ References:
https://github.com/nodemcu/nodemcu-firmware/blob/master/lua_examples/webap_toggle_pin.lua
http://blog.quindorian.org/2015/01/esp8266-wifi-led-dimmer-part-3-of-x.html
--]]

-- Variables
currentDutyCycle = 0
targetDutyCycle = 0
differenceToTarget = 0
fadeTime = 5000
fadeTimeInterval = 0

-- PWM
pwm.setup(3, 1000, 0) -- pin: 3; clock: 1000 (PWM frequency: 1-1000); duty: 0 (PWM duty cycle: 0-1023)
pwm.start(3) -- pin: 3

-- WLAN
wifi.setmode(wifi.STATION)
wifi.sta.config("SSID", "PASSWORD")

config = {}
config.ip = "10.0.0.10"
config.netmask = "255.255.255.0"
config.gateway = "10.0.0.1"
wifi.sta.setip(config)

-- Server
server = net.createServer(net.TCP, 10) -- time out for inactive client: 10 s
server:listen(80, function(connection) -- port: 80
  connection:on("receive", function(client, request)
    local _, _, method, path, argsBlob = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")

    if not method then -- no arguments
      _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
    end

    local args = {}
    if argsBlob then

      for name, value in string.gmatch(argsBlob, "(%w+)=(%w+)&*") do
        args[name] = value
      end
    end

    if args.target then
      local target = tonumber(args.target)

      if (target and target <= 1023) then
        targetDutyCycle = target

        differenceToTarget = targetDutyCycle - currentDutyCycle

        if differenceToTarget < 0 then
          differenceToTarget = differenceToTarget * -1
        end

        if differenceToTarget == 0 then
          differenceToTarget = 1
        end

        fadeTimeInterval = fadeTime / differenceToTarget

        if fadeTimeInterval == 0 then
          fadeTimeInterval = 1
        end

        tmr.alarm(0, fadeTimeInterval, 1, function() -- id: 0 (alarm ID: 0-6); interval: fadeTimeInterval (alarm interval in ms), repeat: yes (repeat alarm: 0-1)
          if currentDutyCycle < targetDutyCycle then
            currentDutyCycle = currentDutyCycle + 1
            pwm.setduty(3, currentDutyCycle) -- pin: 3; duty: currentDutyCycle
          elseif currentDutyCycle > targetDutyCycle then
            currentDutyCycle = currentDutyCycle - 1
            pwm.setduty(3, currentDutyCycle) -- pin: 3; duty: currentDutyCycle
          elseif currentDutyCycle == targetDutyCycle then
            tmr.stop(0) -- id: 0 (alarm ID: 0-6);
          end
        end)

      end
    end

    local response = [[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>LED</title>
<style>
* {
    margin: 0;
    padding: 0;
}

body {
    font: normal 100% 'DejaVu Sans', Arial, Helvetica, 'Liberation Sans', FreeSans, sans-serif;
    background-color: #acc;
}

form {
    margin: 10% auto;
    text-align: center;
}

input {
    display: inline-block;
    font-size: 1.5em;
}

input[type=range] {
    width: 45%;
}

input[type=submit] {
    width: 5%;
    vertical-align: top;
}
</style>
</head>
<body>
<form method="get">
    <input type="range" name="target" min="0" max="1023" step=33 value=]]..targetDutyCycle..[[>
    <input type="submit" value="⟳">
</form>
</body>
</html>]]

    client:send("HTTP/1.1 200 OK\r\nServer: random (NodeMCU)\r\nContent-Type: text/html; charset=utf-8\r\n\r\n"..response)
    client:close()

    collectgarbage() -- perform a full garbage collection
  end)
end)
