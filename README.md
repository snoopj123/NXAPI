# PowerShell Module for Cisco NX-API
(for Nexus 5000/7000 series switches)

Welcome to my community based PowerShell module for use with Cisco Nexus 5000/7000 series switches running NX-API.  My entire goal for this project was to get away from using Cisco UCS Director's implementation of NX-OS interaction (which involved a heavy amount of slow Java code and SSH screenscraping with XML formatting to polish off the object returns).  The code was clunky, prone to performance problems, and introduced a heavy overhead to each of the commands being ran.

This was the compromise that I came up with.  Utilizing Cisco UCS Director's PowerShell Agent Service, I would initiate these API calls (through either HTTP or HTTPS) and deliver the CLI code that was necessary to implement L2 VLAN provisioning on a FabricPath implementation across a Nexus 5000/7000 switching fabric.

More information on the NX-API version included with the Nexus 5000/7000 family of switches can be found [here](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus7000/sw/programmability/guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide_chapter_0101.html).

## The Code

Now, the code is setup in a PowerShell module file (.psm1) that has an associated manifest file (.psd1) so that you could create a subfolder in your PowerShell modules directory and find the module via the _Import-Module_ cmdlet (ex: **Import-Module -ListAvailable**).  You can also just gather the .psm1 file and put the literal path to it in the cmdlet and accomplish the same goal.  I will preface that I expect this code to be ran, as a minimum, PowerShell 5.0.  At the time of this release, I have tested the functions in the module with PowerShell Core 6.0 on macOS.  They did work, but, that wasn't the intended PowerShell version of choice.  Your mileage _may_ vary on newer PowerShell versions.

## The Functions

