# PowerShell Module for Cisco NX-API
(for Nexus 5000/7000 series switches)

Welcome to my community based PowerShell module for use with Cisco Nexus 5000/7000 series switches running NX-API.  My entire goal for this project was to get away from using Cisco UCS Director's implementation of NX-OS interaction (which involved a heavy amount of slow Java code and SSH screenscraping with XML formatting to polish off the object returns).  The code was clunky, prone to performance problems, and introduced a heavy overhead to each of the commands being ran.

This was the compromise that I came up with.  Utilizing Cisco UCS Director's PowerShell Agent Service, I would initiate these API calls (through either HTTP or HTTPS) and deliver the CLI code that was necessary to implement L2 VLAN provisioning on a FabricPath implementation across a Nexus 5000/7000 switching fabric.

More information on the NX-API version included with the Nexus 5000/7000 family of switches can be found [here](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus7000/sw/programmability/guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide/b_Cisco_Nexus_7000_Series_NX-OS_Programmability_Guide_chapter_0101.html).

## The Code

Now, the code is setup in a PowerShell module file (.psm1) that has an associated manifest file (.psd1) so that you could create a subfolder in your PowerShell modules directory and find the module via the _Import-Module_ cmdlet (ex: **Import-Module -ListAvailable**).  You can also just gather the .psm1 file and put the literal path to it in the cmdlet and accomplish the same goal.  I will preface that I expect this code to be ran, as a minimum, PowerShell 5.0.  At the time of this release, I have tested the functions in the module with PowerShell Core 6.0 on macOS.  They did work, but, that wasn't the intended PowerShell version of choice.  Your mileage _may_ vary on newer PowerShell versions.

## The Functions

- **_Set-NXAPIEnv_** - The primary role of this function is to configure the NX-API URI and set the right headers (incuding Basic authentication) for the NX-API call.
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
- **_Get-JsonBody_** - The primary role of this function is to organize the JSON body necessary for the API call, based on the commands given to the function
   - _Parameters_ :
     - **Commands** - A _string_ object that comtains the entire list of commands, semi-colon delimited, to be processed by NX-API.  A good example would be the following: **vlan 1000;name Test;mode fabricpath**.  This function will separate out each command and create the appropriate JSON body for processing.
   - _Returns_ :
     - A _string_ object that contains the JSON formatted body tag for the NX-API call
- **_Initialize-NXAPICall_** - The primary role of this function is to initiate the API call (via _Invoke-WebRequest_) and handle the potential errors that are returned by the NX-API service
   - _Parameters_ :
     - **URI** - **__Required__**: A _string_ object that contains the full URI for initiating the NX-API call
     - **Headers** - **__Required__**: A _hashtable_ object that contains all the pertinent headers for the NX-API call (including the _Content-Type_ and _Authorization_ headers)
     - **Body** - **__Required__**: A _string_ object that is the JSON formatted set of commands to be executed in the NX-API call
     - **EnableVerbose** - A _switch_ object that enables verbose logging of the function and returns execution information
     - **EnableResponse** - A _switch_ object that enables a return string from this function.  Default behavior is for this function to execute, but not return any information
     - **EnableJsonResponse** - A _switch_ object that works in conjunction with _-EnableResponse_ to also return a JSON formatted response to be processed and information returned to the initiating function.  This is useful and explained later in a couple of example functions (like _Add-NXAPIVlan_ and _Remove-NXAPIVlan_)
   - _Returns_ :
     - If _-EnableResponse_ is included in the function call, this function will return some information about the success or failure of the NX-API URI call
     - Otherwise, the function does not return any information and just executes the NX-API call
     