# PowerShell Module for Cisco NX-API
(for Nexus 5000/7000 series switches)

Welcome to my community based PowerShell module for use with Cisco Nexus 5000/7000 series switches running NX-API.  My entire goal for this project was to get away from using Cisco UCS Director's implementation of NX-OS interaction (which involved a heavy amount of slow Java code and SSH screenscraping with XML formatting to polish off the object returns).  The code was clunky, prone to performance problems, and introduced a heavy overhead to each of the commands being ran.

This was the compromise that I came up with.  Utilizing Cisco UCS Director's PowerShell Agent Service, I would initiate these API calls (through either HTTP or HTTPS) and deliver the CLI code that was necessary to implement L2 VLAN provisioning on a FabricPath implementation across a Nexus 5000/7000 switching fabric.

## The Code

Now, the code is setup in a PowerShell module file (.psm1) that has an associated manifest file (.psd1) so that you could create a subfolder in your PowerShell modules directory and find the module via _Import-Module_ cmdlet (ex: **Import-Module -ListAvailable**).  You can also just gather the .psm1 file and put the literal path to it 