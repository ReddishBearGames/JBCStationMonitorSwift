# JBC Station Monitor

### What is this?

This is a tool written in Swift and SwiftUI for monitoring various aspects of JBC's line of Solder and Hot Air stations.  It is based on an on-going reverse engineering of the serial protocol. Since it is currently written as SwiftUI application it only runs on macOS, but there's no reason that the communication part can't be turned into a library that would work anywhere.

### What works

Currently it scans all your serial ports, and lets you try to press "Detect" on each one. If it finds a supported JBC tool connected there, it will collect some configuration data and enter into "Continuous" mode where it will display live information about the tool's state while you use it.

### What doesn't

This has been mostly an effort of reverse engineering, and the list of unsupported things is more extensive than the supported.
- Only tested with a DDE Soldering station and a JTSE Hot Air station, limited tools each. I don't have access to the complete range of very expensive tools!
- Does not support writing/setting of any values. I set out to write a monitoring application so while this could easily be added, it wasn't my goal.
- Does not support firmware updating. I wasn't about to risk my expensive stations on getting this right by trial and error!
- "Robot" mode (RJ-12 port). My first implementation used this mode because it's actually reasonably documented by JBC. But I quickly discovered that when in Robot-mode the tools (reasonably) don't respond to local operation. Since I was interested in monitoring I abandoned this approach. The protocol differs only slightly though (see below), and it wouldn't be terribly hard to add support for both if someone were interested.

## Protocol

I'll get into the USB protocol as I've dissected it so far, but I wanted to give a brief overview of the Robot protocol first because they're somewhat related. Feel free to skip straight to the USB part though.

### Robot Mode
JBC documents the robot protocol in various documents found [here.](https://www.jbctools.com/robots-guide.html)

Robot Mode is designed for completely controlling the station via an external process, so everything from temperature to the on/off state of the heating is completely controlled by the robot. This means that placing the tool in the stand or using pedals are ignored other than as a variable the robot can read. In other words, this mode is only really useful for well, a robot. But I mention it here because it's documented and a good starting point for figuring out the USB protocol.

To activate Robot mode, you set Robot to "YES" on the Station itself, and select communications parameters like Baud and Parity. It supports all the usual options there.

Communication with the device occurs by exchanging "Frames" as packets. Every frame you send will result in a response frame. In Robot mode, frames are of fixed size and either addressed or not. Addressing mode is chosen on the station when enabling the mode - I'm not really sure what purpose it serves.

#### Robot Packet Frame
The anatomy of a data frame is this, where each letter is one byte, items in {} only appear conditionally.

`S {SA TA} H CCC {DDDDD} E X`
	
The meaning of these fields is as follows:

- **`S`** - The Start of a frame character, which is literally ASCII STX (0x02)
- **`SA`** - Source address. The address of the device sending the packet. This is a two-digit value in ASCII so address 1 would be '01' The address to use is defined on the Station when setting up Robot mode. If addressing is disabled, this field is completely omitted.
- **`TA`** - Target address. The address of the device receiving the packet. This is a two-digit value in ASCII so address 1 would be '01' The address to use is defined on the Station when setting up Robot mode. If addressing is disabled, this field is completely omitted.
- **`H`** - Control Header. One of the ASCII characters `R`, `W`, `A` or `N` representing the following:
   - **`R`**: A read command, which is retrieving a value from the device.
   - **`W`**: A write command, which is writing/changing a value on the device.
   - **`A`**: An ACK response from the device to one of the above
   - **`N`**: A NACK (error) response from the device to one of the above
- **`C`** - The command to perform. This is ASCII in the form of, for instance "PS1" which means "Port Status for port 1". The JBC documentation lists the commands which exist, so I won't repeat them here.
- **`DDDDD`** - The data payload. This only appears if you're sending a `W`rite control header, in an ACK response to a `R` control commmand, or in an error `N`ACK response. Otherwise it's completely omitted. It is ALWAYS 5 characters in length, and should be left-padded with ASCII 0s if the value is shorter.
- **`E`** - The End of frame character, which is literally ASCII ETX (0x03)
- **`X`** - A single byte which is the calculated checksum. It's simply an XOR of every previous field.

### USB Serial Mode
Unlike Robot mode, the station does not require you to enable this and does not behave any differently whether or not something is connected. It **requires** the following comm parameters:
- Baud: 500,000
- Stop Bits: 1
- Parity: None
- Databits: 8
- RTS/CTS flow control is recommended.

Note that the baud rate is fairly non-standard and may not be supported by all serial drivers. The macOS drivers do appear to work (as of Sonoma at least, I didn't test earlier releases) but require special care because ```tcsetattr()``` will fail with a value of 500000 set in its options. You have to call:
```c
int newBaud = 500000
ioctl(fd, IOSSIOSPEED, &newBaud, 1)
``` 
In order to get that speed. I don't know whether similar tricks are necessary on other platforms like Linux or Windows.

### USB Packet Frame

Note that there appear to be **two** protocol versions out there, but I don't have a device which speaks V1 so my knowledge of it is limited, and thus this project's code barely mentions it/accounts for it.
#### Protocol 1
`STX SA TA CMD Length {Data} BCC ETX` 

I **think**. Again, I haven't seen this in person and only inferred its existence.
#### Protocol 2
`STX SA TA FID CMD Length {Data} BCC ETX`

The meaning of the fields is as follows:

- **`STX`** - 1 Byte. The Start of a frame character, which is literally ASCII STX (0x02)
- **`SA`** - 1 Byte. Source address, the address of the device sending the packet. When transmitting this is your address, which is determined during the handshake process. When receiving this will be the device's address.
- **`TA`** - 1 Byte. Target address, the address of the device you're sending the packet to. When transmitting this is the station's address which is determined during the handshake process. When receiving this will be the your address.
- **`FID`** - 1 Byte. Frame ID. In normal operation, this is an increasing value starting from 0 that identifies a particular exchange. If you send a command with FID 22, you'll receive a response with FID 22 and can use this to identify matching responses. For normal commands you should simply start with 0 and increment by 1 for every command you send, wrapping around back to 0 when you hit FF. There are two cases I know of where this works a little differently:
  - During handshake, the FID seems to have arbitrary values. If there's a meaning to it, I don't know what it is.
  - During "continuous mode" updates, the station sends update packets with an incremented FID on every new update, wrapping to 0 itself after FF. I believe you're meant to only use the 'newest' if you aren't processing them all fast enough.
- **`CMD`** - 1 Byte. The actual command you're sending. Unlike robot mode, you don't specify Read or Write as a modifier, rather Read and Write versions of the same command will have different but usually (always?) sequential values. The actual commands available vary by station type (Solder vs Hot Air) with some overlap, and the table is not documented that I know of. This tool only supports the subset of commands that I've reverse engineered so far.
- **`Length`** - 1 Byte. The number of bytes present in the data payload. This can be 0 in which case there will be no data payload field at all.
- **`{Data}`** - 0 - 255 Bytes. The data payload. **MOST** commands will respond with a payload, and many commands you send require a payload containing arguments. The format of this payload is not documented, and most of the difficulty in implementing a new command is reverse engineering the meaning of the data payloads. The payloads for sent commands tend to be quite straightforward fortunately. Note that this data is raw and not ASCII like the Robot version.
- **`BCC`** - All the bytes of the frame XOR'd together EXCLUDING of course the BCC field itself - but still includes the ETX at the end of the frame.
- **`ETX`** - 1 Byte. The End of frame character, which is literally ASCII ETX (0x03)

#### Frame Encoding

You might have realized that this protocol, in contrast to the Robot version, is binary and not ASCII based. That means that the STX and ETX control characters might actually appear naturally in the middle of a frame. Because of this, frames have to be encoded and decoded before transmission and after receipt. This is done by using the Data Link Escape (DLE, ASCII 0x10). The STX and ETX characters bookending the frame must be preceeded with DLE - and **only** the bookending occurrences of 0x02 and 0x03. Any other occurrences mid-frame should be ignored. If 0x10 appears anywhere in the middle of a frame, an additional 0x10 needs to be inserted to "escape" it.

Note that this encoding must occur *after* the frame is formed and is not considered part of the frame itself. So these DLE characters are not part of the BCC calculation.