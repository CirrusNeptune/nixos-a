# IR @ Furry House
In our smarthome ecosystems we use infrared light based commands to control local
media devices that have no other way of being controlled in a way that meets our
requirements. 

As of 02/17/2025 the only device that needs these IR commands is our
Nakamichi surround sound system. We have it tied to CEC as well but CEC cannot send 
all the commands we need to control the device such as controlling different speaker
sounds and setting the correct sound mode for the media experience.

## Architecture
### Sending an IR Command
1. A custom home assistant module in a container sends a string command over a socket to the [lirc daemon](https://github.com/CirrusNeptune/nixos-a/blob/main/modules/services/lirc.nix)
2. That command is read by the lirc daemon which then maps the string to the binary IR command to send. The signal to send is sent to the [iguanair kernel](https://github.com/torvalds/linux/blob/master/drivers/media/rc/iguanair.c).
3. The iguana kernel sends the command to the [iguana ir device](https://www.iguanaworks.net/products/usb-ir-transceiver/) that emits the signal
4. The receiving IR signal device takes in the command and adjusts as needed to fit the use case 

# Resources
[lirc docs](https://www.lirc.org/html/index.html) - lirc system docs <br> 
[iguanaworks](https://www.iguanaworks.net/) - IR transceiver manufacturer's website<br> 
[nakamichi](https://www.nakamichi-usa.com/) - stereo manufacturer's website. we have a shockwave 7.1.2 setup, but we cannot find the specific model on their site anymore
