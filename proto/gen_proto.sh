#!/bin/sh

sudo protoc --descriptor_set_out pbhead.pb pbhead.proto
sudo protoc --descriptor_set_out pbcommon.pb pbcommon.proto
sudo protoc --descriptor_set_out pblogin.pb pblogin.proto
sudo protoc --descriptor_set_out pbplayer.pb pbplayer.proto
