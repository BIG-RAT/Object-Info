# Object Info

Wondering what packages or scripts are scoped to what policies?  Or what configuration profiles contain a certain payload?  Need an overview of all your network segments?  How about finding out what object(s) smart/static groups are attached to?  Object info looks to summarize these things.

Download: [Object Info](https://github.com/BIG-RAT/Object-Info/releases/download/current/Object.Info.zip)

![alt text](./images/ObjectInfo.png "Object Info")

**Current Searches**:

* Find policies that update inventory.
* Find IP range, default share name, and URL associated with a network segment.
* Find what policies and computer configurations a package is associated with.
* Find what policies and computer configurations a script is associated with.
* Find what policies, configuration profiles, and apps a computer group is associated with.
* Find what configuration profiles, and apps a device group is associated with.
* Find macOS configuration profiles containing a particular payload.
* Find where extension attributes (computer/mobile device) are used in groups and advanced searches.

	**Currently available payloads**:
	
	* AD Certificate
	* Certificate
	* Directory
	* Dock
	* Energy Saver
	* Kernel Extensions
	* Login Items
	* Login Window
	* Mobility
	* Network
	* Printing
	* Passcode
	* Restrictions
	* SCEP
	* Security & Privacy 
	* Software Update
	* System Extensions
	* VPN

* Find iOS configuration profiles containing a particular payload.  
	**Currently available payloads:**
	
	* Exchange ActiveSync
	* Google Account
	* Home Screen Layout
	* Mail
	* Passcode
	* Restrictions
	* Single App Mode
	* VPN
	* WebClip
	* Wi-Fi


<hr>

**History**

2021-06-17: Version 1.1.3 - Fix crash when config profile has no payload.

2021-01-14: Version 1.1.1 - Added ability to sort column results.  Fixed some issues where scoped objects were not listed.