------------------------------------------------------------------------------
--
--  LGI Gst override module.
--
--  Copyright (c) 2010, 2011 Pavel Holejsovsky
--  Licensed under the MIT license:
--  http://www.opensource.org/licenses/mit-license.php
--
------------------------------------------------------------------------------

local lgi = require 'lgi'
local gi = require('lgi._core').gi
local GLib = lgi.GLib
local Gst = lgi.Gst

-- GstObject has special ref_sink mechanism, make sure that lgi core
-- is aware of it, otherwise refcounting is screwed.
Gst.Object._sink = gi.Gst.Object.methods.ref_sink

-- Gst.Bin adjustments
function Gst.Bus:add_watch(callback)
   return self:add_watch_full(GLib.PRIORITY_DEFAULT, callback)
end

function Gst.Bin:add_many(...)
   local args = {...}
   for i = 1, #args do self:add(args[i]) end
end

-- Gst.TagList adjustments
if not Gst.TagList.copy_value then
   Gst.TagList._methods.copy_value = Gst.tag_list_copy_value
end
function Gst.TagList:get(tag)
   local ok, value = self:copy_value(tag)
   return ok and value.data
end

-- Load additional Gst modules.
local GstInterfaces = lgi.GstInterfaces

-- Initialize gstreamer.
Gst.init()
