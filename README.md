csgo-map-testing
===========================

[![Build status](http://ci.splewis.net/job/csgo-pug-setup/badge/icon)](http://ci.splewis.net/job/csgo-pug-setup/)

This is a simple plugin intended for facilitating some light playtesting of CS:GO maps, originally created for the [MapCore](mapcore.org) community.

What it does:

1. Launches a warmup period when the first client connects
2. Once 10 players connect the warmup period resets
3. Once warmup ends, the game starts normally
4. Polls are given at the 2nd and 2nd-to-last automatically
5. 3 things are logged into seperate files: 1) all chat messages, 2) feedback via the !feedback/!b/!gf command, and 3) the output of any polls made

## Downloads

You should be able to get the most recent download from https://github.com/splewis/csgo-map-testing/releases.

You may also download the [latest development build](http://ci.splewis.net/job/csgo-map-testing/lastSuccessfulBuild/) if you wish. If you report any bugs from these, make sure to include the build number (when typing ``sm plugins list`` into the server console, the build number will be displayed with the plugin version).

## Installation

**Sourcemod 1.7 is required.**

Download maptesting.zip from the [downloads section](https://github.com/splewis/csgo-map-testing/releases) and extract the files to the game server. You can simply upload the ``addons`` and ``cfg`` directories to the server's ``csgo`` directory and be done.

 From the download, you should have installed the following (to the ``csgo`` directory):
- ``addons/sourcemod/plugins/maptesting.smx``
- ``addons/sourcemod/translations/`` (the entire directory)
- ``cfg`` (the entire directory)

## Commands

- ``sm_poll <title> <options1> <option2> ...`` to create a poll that will be logged automatically

## Configuration

Install the plugin, launch the server, and edit the autogenerated ``cfg/sourcemod/maptesting.cfg`` file.
