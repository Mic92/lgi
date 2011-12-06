------------------------------------------------------------------------------
--
--  LGI Gtk3 override module.
--
--  Copyright (c) 2010, 2011 Pavel Holejsovsky
--  Licensed under the MIT license:
--  http://www.opensource.org/licenses/mit-license.php
--
------------------------------------------------------------------------------

local select, type, pairs, ipairs, unpack, setmetatable, error
   = select, type, pairs, ipairs, unpack, setmetatable, error
local lgi = require 'lgi'
local core = require 'lgi.core'
local Gtk = lgi.Gtk
local Gdk = lgi.Gdk
local GObject = lgi.GObject

-- Gtk.Allocation is just an alias to Gdk.Rectangle.
Gtk.Allocation = Gdk.Rectangle

-------------------------------- Gtk.Widget overrides.
Gtk.Widget._attribute = {}

-- gtk_widget_intersect is missing an (out caller-allocates) annotation
if core.gi.Gtk.Widget.methods.intersect.args[2].direction == 'in' then
   local real_intersect = Gtk.Widget.intersect
   function Gtk.Widget._method:intersect(area)
      local intersection = Gdk.Rectangle()
      local notempty = real_intersect(self, area, intersection)
      return notempty and intersection or nil
   end
end

-- Accessing style properties is preferrably done by accessing 'style'
-- property.  In case that caller wants deprecated 'style' property, it
-- must be accessed by '_property_style' name.
Gtk.Widget._attribute.style = {}
local widget_style_mt = {}
function widget_style_mt:__index(name)
   name = name:gsub('_', '%-')
   local pspec = self._widget.class:find_style_property(name)
   if not pspec then
      error(("%s: no style property `%s'"):format(
	       self._widget.type._name, name:gsub('%-', '_')), 2)
   end
   local value = GObject.Value(pspec.value_type)
   self._widget:style_get_property(name, value)
   return value.value
end
function Gtk.Widget._attribute.style:get()
   return setmetatable({ _widget = self }, widget_style_mt)
end

-------------------------------- Gtk.Buildable overrides.
Gtk.Buildable._attribute = { id = {}, child = {} }

-- Create custom 'id' property, mapped to buildable name.
function Gtk.Buildable._attribute.id:set(id)
   Gtk.Buildable.set_name(self, id)
end
function Gtk.Buildable._attribute.id:get()
   return Gtk.Buildable.get_name(self)
end

-- Custom 'child' property, which returns widget in the subhierarchy
-- with specified id.
local buildable_child_mt = {}
function buildable_child_mt:__index(id)
   return self._buildable.id == id and self._buildable or nil
end
function Gtk.Buildable._attribute.child:get()
   return setmetatable({ _buildable = self }, buildable_child_mt)
end

-------------------------------- Gtk.Container overrides.
Gtk.Container._attribute = {}

-- Extand add() functionality to allow adding child properties.
function Gtk.Container:add(widget, props)
   if type(widget) == 'table' then
      props = widget
      widget = widget[1]
   end
   Gtk.Container._method.add(self, widget)
   if props then
      local properties = self.property[widget]
      for name, value in pairs(props) do
	 if type(name) == 'string' then
	    properties[name] = value
	 end
      end
   end
end

-- Map 'add' method also to '_container_add', so that ctor can use it
-- for adding widgets from the array part.
Gtk.Container._container_add = Gtk.Container.add

-- Accessing child properties is preferrably done by accessing
-- 'property' attribute.
Gtk.Container._attribute.property = {}
local container_property_item_mt = {}
function container_property_item_mt:__index(name)
   name = name:gsub('_', '%-')
   local pspec = self._container.class:find_child_property(name)
   if not pspec then
      error(("%s: no child property `%s'"):format(
	       self._container.type._name, name:gsub('%-', '_')), 2)
   end
   local value = GObject.Value(pspec.value_type)
   self._container:child_get_property(self._child, name, value)
   return value.value
end
function container_property_item_mt:__newindex(name, val)
   name = name:gsub('_', '%-')
   local pspec = self._container.class:find_child_property(name)
   if not pspec then
      error(("%s: no child property `%s'"):format(
	       self._container.type._name, name:gsub('%-', '_')), 2)
   end
   local value = GObject.Value(pspec.value_type, val)
   self._container:child_set_property(self._child, name, value)
end
local container_property_mt = {}
function container_property_mt:__index(child)
   return setmetatable({ _container = self._container, _child = child },
		       container_property_item_mt)
end
function Gtk.Container._attribute.property:get()
   return setmetatable({ _container = self }, container_property_mt)
end

-- Override 'child' attribute; writing allows adding child with
-- children properties (similarly as add() override), reading provides
-- table which can lookup subchildren by Gtk.Buildable.id.
Gtk.Container._attribute.child = {}
local container_child_mt = {}
function container_child_mt:__index(id)
   local found = (Gtk.Buildable.get_name(self._container) == id
	       and self._container)
   if not found then
      for _, child in ipairs(self) do
	 found = child.child[id]
	 if found then break end
      end
   end
   return found or nil
end
function Gtk.Container._attribute.child:get()
   local children = self:get_children()
   children._container = self
   return setmetatable(children, container_child_mt)
end
function Gtk.Container._attribute.child:set(widget)
   self:add(widget)
end

-------------------------------- Gtk.Builder overrides.
Gtk.Builder._attribute = {}

-- Override add_from_ family of functions, their C-signatures are
-- completely braindead.
local function builder_fix_return(res, e1, e2)
   if res and res ~= 0 then return true end
   return false, e1, e2
end
function Gtk.Builder:add_from_file(filename)
   return builder_fix_return(Gtk.Builder._method.add_from_file(self, filename))
end
function Gtk.Builder:add_objects_from_file(filename, object_ids)
   return builder_fix_return(Gtk.Builder._method.add_objects_from_file(
				self, filename, object_ids))
end
function Gtk.Builder:add_from_string(string, len)
   if not len or len == -1 then len = #string end
   return builder_fix_return(Gtk.Builder._method.add_from_string(
				self, string, len))
end
function Gtk.Builder:add_objects_from_string(string, len, object_ids)
   if not len or len == -1 then len = #string end
   return builder_fix_return(Gtk.Builder._method.add_objects_from_string(
				self, string, len, object_ids))
end

-- Wrapping get_object() using 'objects' attribute.
Gtk.Builder._attribute.objects = {}
local builder_objects_mt = {}
function builder_objects_mt:__index(name)
   return self._builder:get_object(name)
end
function Gtk.Builder._attribute.objects:get()
   return setmetatable({ _builder = self }, builder_objects_mt)
end

-------------------------------- Gtk.TextTagTable overrides.
Gtk.TextTagTable._attribute = { tag = {} }

local text_tag_table_tag_mt = {}
function text_tag_table_tag_mt:__index(id)
   return self._table:lookup(id)
end
function Gtk.TextTagTable._attribute.tag:get()
   return setmetatable({ _table = self }, text_tag_table_tag_mt)
end

-- Map adding of tags in constructor array part to add() method.
Gtk.TextTagTable._container_add = Gtk.TextTagTable.add

-- Initialize GTK.
Gtk.init()