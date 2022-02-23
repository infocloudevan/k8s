# Read Me for Provisioning Files

## About the files

The hardware directory contains the configuration script for setting up a hardware appliance through the Mint Linux Live USB. This file should not be changed without Keith's involvement.

The templates directory contains all the master templates for provisioning an appliance.

The `create-mac.sh` and `create-linux.sh` script is what is used to provision a new appliance. They differ per platform mainly with the `sed` instructions.