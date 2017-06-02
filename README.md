# Set Attribute Values Plugin

This plugin adds possibility to set default attribute values in a request form and change them dynamically.

# !!! IMPORTANT !!!:
Since MSM system doesn't have specific web services to retrieve action message information by default, MSM Web Service Extensions are required (not included here).
Only if/when new api methods will be implemented in MSM system this package could be used in your systems.
Please feel free to contact Marval Baltic if you would like to see it working.

## Compatible Versions

| Plugin  | MSM              |
|---------|------------------|
| 1.2.0   | 14.3.1 - 14.5.1  |

## Installation

Please see your MSM documentation for information on how to install plugins.

Once the plugin has been installed you need to specify these plugin parameters:
* Rules Action Message - Name or ID of MSM Action Message to be used as container for plugin rules stored as json object.
* MSM WSE Address - MSM Web Service Extensions (WSE) address
* MSM WSE User Name - MSM Web Service Extensions user name (can be encrypted WSE specific way)
* MSM WSE Password - MSM Web Service Extensions password (can be encrypted WSE specific way)

## Usage

The plugin is automatically launched when loading a request form.

## Contributing

 Any feedback is very welcome.