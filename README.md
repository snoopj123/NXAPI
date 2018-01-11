# PowerShell Module for Cisco NX-API
(for Nexus 5000/7000 series switches)

Welcome to my community based PowerShell module for use with Cisco Nexus 5000/7000 series switches running NX-API.  My entire goal for this project was to get away from using Cisco UCS Director's implementation of NX-OS interaction (which involved a heavy amount of slow Java code and SSH screenscraping with XML formatting to polish off the object returns).  The code was clunky, prone to performance problems, and introduced a heavy overhead to each of the commands being ran.

This was the compromise that I came up with.  Utilizing Cisco UCS Director's PowerShell Agent Service, I would initiate these API calls (through either HTTP or HTTPS) and deliver the CLI code that was necessary to implement L2 VLAN provisioning on a FabricPath implementation across a Nexus 5000/7000 switching fabric.

More information on the NX-API version included with the Nexus 5000/7000 family of switches can be found [here](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus7000/sw/programmability/guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide_chapter_0101.html).

## The Code

Now, the code is setup in a PowerShell module file (.psm1) that has an associated manifest file (.psd1) so that you could create a subfolder in your PowerShell modules directory and find the module via the _Import-Module_ cmdlet (ex: **Import-Module -ListAvailable**).  You can also just gather the .psm1 file and put the literal path to it in the cmdlet and accomplish the same goal.  I will preface that I expect this code to be ran, as a minimum, PowerShell 5.0.  At the time of this release, I have tested the functions in the module with PowerShell Core 6.0 on macOS.  They did work, but, that wasn't the intended PowerShell version of choice.  Your mileage _may_ vary on newer PowerShell versions.

## The Functions

- _Set-NXAPIEnv_ - The primary role of this function is to configure the NX-API URI and set the right headers (incuding Basic authentication) for the NX-API call.
    - _Parameters_ :
      - **Switch** - **__Required__**.  This is a _string_ object that is either the IP address or FQDN (fully qualified domain name) of the switch that is running NX-API
      - **Username** - **__Required__**.  This is a _string_ object that contains the username for which we will be authenticating into the switch that is running NX-API
      - **Password** - **__Required__**.  This is a _SecureString_ object that contains the password for the account we will be authentication with, into the switch that is running NX-API
      - **Secure** - This is a _switch_ object that when present, will setup the URI to the NX-API endpoint to use HTTPS (assuming the switch has valid certificates installed) for the API communication.  Default behavior of the function is to configure URIs with a HTTP designation.
      - **Port** - This is an _int_ object that when present will add the port number that NX-API has been configured with.  (ex: **http://testserver:8080/ins**)
    - _Returns_ :
      - A _hashtable_ object containing three Key/Value pairs
        - **URI** - A _string_ that has the entire URI (including potential changes to the port and/or connection protocol)
        - **auth\_header** - A _string_ that contains the Basic authorization header, already configured, based on the username and password passed to the function
        - **content-type** - A _string_ that contains the content-type header value, defaulted to use _application/json-rpc_