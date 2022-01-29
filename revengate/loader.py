#! /usr/bin/env python3

# Copyright © 2020, 2021 Yannick Gingras <ygingras@ygingras.net>

# This file is part of Revengate.

# Revengate is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Revengate is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Revengate.  If not, see <https://www.gnu.org/licenses/>.

""" Object creation from json or toml data. 

The files must deserialize to a dictonary with at least a "RevengateFile" 
section with the following fields:
- format: an integer describing the format version 
- content: a key describing the sub-loader to invoke to decode the data into 
Python instances.

See the documentation of various sub-classes of SubLoader for the various data 
representations that are supported. 

"""

import os
import sys
import json
import inspect
from random import randrange
from pprint import pprint

import tomlkit

# classes loaders can instantiate; this could be factored out
from . import tags
from .tags import Tag
from .strategies import Strategy
from .items import Item
from .weapons import HealthVector, Effect
from .actors import Actor

TOP_SECTION = "RevengateFile"
FORMAT = 0


class Template:
    """ Template are recipes for creating entities.  
    
    Resulting entities can be fully initialized or only partialy so. Invoking 
    a template to produce an instance must be done by a factory, typically a 
    SubLoader.
    """

    def __init__(self, name, parent=None, fields=None):
        super(Template, self).__init__()
        # Templates must know their name,  it simplifies the inheritance 
        # resolution
        self.name = name  
        self.parent = parent
        self.fields = fields or {}


class TopLevelLoader:
    """ Initial file loader: do some file validation, then invoke the 
    appropriate sub-loader(s) based on content type. """

    def __init__(self, engine=None):
        # We keep the sub-loader used for each file. Template invocation and 
        # instance lookup is defered to them.
        self.master_file = None
        self.sub_loaders = {}  # content_key -> instance
        
        # TODO: see the comment on TemplatizedObjectsLoader
        self.engine = engine

    def load(self, fp):
        serializer = None
        if fp.name:
            if self.master_file is None:
                self.master_file = fp.name
            if fp.name.endswith(".toml"):
                serializer = tomlkit
            elif fp.name.endswith(".json"):
                serializer = json
        return self.loads(fp.read(), serializer)
        
    def loads(self, data, serializer=None):
        if serializer is None:
            # assume json if it does not look like TOML 
            if data.lstrip().startswith(f"[{TOP_SECTION}]"):
                serializer = tomlkit
            else:
                serializer = json
                
        root_record = serializer.loads(data)
        file_info = root_record[TOP_SECTION]
        file_format = file_info["format"]
        if file_format != FORMAT:
            raise ValueError(f"Unsupported file format: {file_format}. "
                             f"This loader expects {FORMAT}")

        content_type = file_info["content"]
        if content_type not in self.sub_loaders:
            for cls in SubLoader.__subclasses__():
                if cls.content_key == content_type:
                    self.sub_loaders[content_type] = cls(self, self.engine)
                    break
            else:
                # we got to the end of the loop without finding a sub-loader
                raise ValueError("Could not find a SubLoader for " 
                                 f"{content_type}")
        loader = self.sub_loaders[content_type]
        return loader.decode(root_record)

    def invoke(self, template):
        for loader in self.sub_loaders.values():
            obj = loader.invoke(template)
            if obj:
                return obj
        raise ValueError(f"Could not find a sub-loader to handle {template}.")
        
    def get_instance(self, name):
        for loader in self.sub_loaders.values():
            obj = loader.get_instance(name)
            if obj:
                return obj
        raise ValueError("Could not find a sub-loader with an instance "
                         f"registered as {name}.")


class SubLoader:
    """ Base class for inner content loaders. 
    
    Content discovery is based on the `content_key` class attribute. """
    
    content_key = None

    def __init__(self, top_loader, engine=None):
        self.top_loader = top_loader
        # TODO: 'engine' could be easily factored our as a more generic dict
        # of instance values to set by the loader. "defaults" would be a good 
        # name for it
        self.engine = engine  

    def decode(self, record):
        raise NotImplementedError()

    def invoke(self, template):
        raise NotImplementedError()
        
    def get_instance(self, name):
        raise NotImplementedError()


class FileMapLoader(SubLoader):
    """ Load content that is spread across multiple files. 
    
    The 'RevengateFile' section must have a 'files' attribute: a list of 
    filenames.
    
    Files must be in the same directory as the master file or fully qualified 
    paths must be supplied. Files can contain anything for which there is a 
    valid loader, including another file-map. 
    
    Example:
    [RevengateFile]
    format = 0
    content = "file-map"
    files = ["sim-1.toml", "sim-2.toml"]
    """
    
    content_key = "file-map"

    def __init__(self, top_loader, engine=None):
        super(FileMapLoader, self).__init__(top_loader, engine)

    def locate(self, filename):
        """ Return a qualified location for filename. """
        if os.path.isfile(filename):
            return filename
        if self.top_loader.master_file:
            master_dir = os.path.dirname(self.top_loader.master_file)
            qual_name = os.path.join(master_dir, filename)
            if os.path.isfile(qual_name):
                return qual_name
        return ValueError(f"Can't find {filename!r}. Try supplying an "
                          "absolute path.")
        
    def decode(self, record):
        objs = []
        for fname in record[TOP_SECTION]["files"]:
            with open(self.locate(fname), "rt") as fp:
                objs.append(self.top_loader.load(fp))
        return objs

    def invoke(self, template):
        return None
        
    def get_instance(self, name):
        return None


class TemplatizedObjectsLoader(SubLoader):
    """ Factory class for creating templatized object instances.
    
    Object templates specify some or all the fields of an object with the values 
that they should be initialized to. Templates can inherit some of their values 
from parent templates and they can apply basic transforms to the parent values. 
Values can also be initialized with random numbers inside the specified range. 

    Two sections must be present: 'instances' and 'templates'. Both are 
name->definition mappings. Instances are initialized when calling decode() on a 
file. Templates must be invoked by calling invoke() to create a new instance.
    
    Special fields:
    _class: the class to instanciate
    _parent: another template that this template inherits from

    field names can be prefixed by the following for special action:
    '+': add value to the value of the parent template (appends with lists)
    '-': subtrack value to the value of the parent (not implemented for lists)
    '!': random value, pass the max int or a [min, max] list for a range

    values can be prefixed by the following for special actions:
    '*': invoke a sub-template by name
    '#': invoke a tag by name, similar to tags.t()

    Fields that are named in the constructor of an object's Python class are 
    set at creation time. All the other fields are set after the object has 
    been created. 
    
    Example:
    [RevengateFile]
    format = 0
    content = "templatized-objects"

    # no instances but we still should declare the section
    [instances]

    # create this very average person by calling loader.invoke("bob")
    [templates.bob]
    _class = "Humanoid"
    name = "bob"
    health = 80
    armor = 0
    strength = 50
    agility = 50
    intelligence = 50
    spells = []

    """
    
    content_key = "templatized-objects"

    def __init__(self, top_loader, engine=None):
        super(TemplatizedObjectsLoader, self).__init__(top_loader, engine)
        
        self._class_map = {} # name -> class object mapping
        
        # for by-name invokations
        self._instances = {} 
        self._templates = {}
        
        # Templates and instances can only be for those and their sub-classes. 
        # It would make sens to factor this out at some point. 
        for cls in [Tag, Item, HealthVector, Effect, Strategy, Actor]:
            self._map_class_tree(cls)
        
    def _map_class_tree(self, cls):
        """ Add all the subclasses of cls to the class map. """
        self._class_map[cls.__name__] = cls
        for sub in cls.__subclasses__():
            self._map_class_tree(sub)

    def _expand_one(self, field):
        """ Expand invokations (tags and templates), and generators in field.
        
        Return the field unmodified if there are no references. """
        if callable(field):
            return field()
        if isinstance(field, str) and field.startswith("#"):  # tag
            return tags.t(field[1:])
        if isinstance(field, str) and field.startswith("*"):  # sub-template
            return self.invoke(field[1:])
        return field

    def _instanciate(self, cls_name, fields, template_name=None):
        """ Create an instance of cls_name with all the fields specified.
        
        As many fields as possible are passed to the constructor, the other 
        ones are set as attributes after creation. 
        """
        cls = self._class_map[cls_name]
        # apply fields references
        for k, v in list(fields.items()):
            if isinstance(v, str) or callable(v):
                fields[k] = self._expand_one(v)
            if isinstance(v, list):
                fields[k] = [self._expand_one(s) for s in v]
        # find which fields are contructor friendly
        init_args = {}
        params = inspect.signature(cls).parameters
        for arg in params:
            if arg in fields:
                init_args[arg] = fields.pop(arg)
                
        # 'name' is a special case: it's often the same at the Template name
        if "name" in params and "name" not in init_args:
            if template_name:
                init_args["name"] = template_name
        
        obj = cls(**init_args)
        # set the other fields after creation
        for attr in fields:
            setattr(obj, attr, fields[attr])
        if hasattr(obj, "engine") and self.engine:
            obj.engine = self.engine
        return obj
  
    def _decode_template(self, name, rec):
        """ Convert a single record to template that can later be invoked 
        by `name`. """
        parent = rec.pop("_parent", None)
        obj = Template(name, parent, rec)
        self._templates[name] = obj
        return obj
  
    def _decode_instance(self, name, rec):
        """ Convert a single record to an instance. """
        if "_parent" in rec:
            msg = f"Parent specified in an instance record name: {rec}"
            raise ValueError(msg)
    
        obj = self._instanciate(rec.pop("_class"), rec)
        self._instances[name] = obj
        return obj

    def _stack_str(self, stack):
        """ Return a printable summary of a template stack. """
        return "->".join([t.name for t in stack])
    
    def decode(self, rec):
        # only instances and templates for the current file are returned
        instances = {}
        for name, subrec in rec["instances"].items():
            obj = self._decode_instance(name, subrec)
            instances[name] = obj
        templates = {}
        for name, subrec in rec["templates"].items():
            obj = self._decode_template(name, subrec)
            templates[name] = obj
        return dict(instances=instances, templates=templates)
        
    def _random_field(self, val):
        """ Convert val into a random generator.
        
        val: either max or a [min, max] list.
        The generator is called at invokation time.
        """
        if isinstance(val, int):
            return lambda: randrange(val+1)
        elif isinstance(val, list):
            min, max = val
            return lambda: randrange(min, max+1)
        else:
            raise ValueError(f"Don't know how to turn {val} into a random"
                             " generator.")

    def _add_to_field(self, parent_val, val):
        """ Add val to parent_val.
        
        List operations (append) are supported. 
        """
        if isinstance(parent_val, int):
            return parent_val + val
        if isinstance(parent_val, list):
            if isinstance(val, list):
                return parent_val + val
            else:
                parent_val.append(val)
                return parent_val
        raise ValueError(f"Adding ${val} to base value ${parent_val} is"
                         " unsupported.")

    def _sub_from_field(self, parent_val, val):
        """ Subtract val from parent_val.
        
        List operations (filter out) are supported. 
        """
        if isinstance(parent_val, int):
            return parent_val - val
        if isinstance(parent_val, list):
            if isinstance(val, list):
                return [e for e in parent_val if e not in val]
            else:
                return [e for e in parent_val if e != val]
        raise ValueError(f"Subtracting ${val} from base value ${parent_val} is"
                         " unsupported.")


    def invoke(self, template):
        """ Instanciate an object based on a template.  
        
        The template can be a name or a Template intsance. 
        """
        if not isinstance(template, Template):
            template = self._templates[template]
        
        # resolution is two steps: 
        # 1) find all the parents
        # 2) populate all the fields starting at the oldest ancestor
        oname = template.name # the original name before we resolve inheritance
        seen = set() # to prevent infinite loops
        stack = []
        while template is not None:
            if template.name in seen:
                cycle = self._stack_str(stack+[template])
                msg = (f"Inheritance cycle detected while processing {oname} "
                       f"({cycle})")
                raise ValueError(msg)
            seen.add(template.name)
            stack.append(template)
            if template.parent:
                template = self._templates[template.parent]
            else:
                template = None
        
        fields = {}
        for t in reversed(stack):
            tfields = dict(t.fields) # we don't want to modify the original
            # manually apply the fields with special overrides: +, -, ...
            for prefix, action in [("!", self._random_field)]: # single actions
                keys = [k for k in tfields if k.startswith(prefix)]
                for k in keys:
                    v = tfields.pop(k)
                    k = k[1:]
                    fields[k] = action(v)
            for prefix, action in [("+", self._add_to_field), 
                                   ("-", self._sub_from_field)]: # transforms
                keys = [k for k in tfields if k.startswith(prefix)]
                for k in keys:
                    v = tfields.pop(k)
                    k = k[1:]
                    if k in fields:
                        fields[k] = action(fields[k], v)
                    else: 
                        raise ValueError(f"Field {k!r} in template {oname!r}"
                                         f" has no parent value. " 
                                         f"Can't apply {prefix!r} transform.")
            # batch apply the other fields
            fields.update(tfields)
        return self._instanciate(fields.pop("_class"), fields, oname)

    def get_instance(self, name):
        return self._instances.get(name)


def main():
    loader = TopLevelLoader()
    objs = loader.load(open(sys.argv[1], "rt"))
    pprint(objs)
    print(loader.get_instance("beasts"))
    print(loader.invoke("hero"))
    print(loader.invoke("bob").weapon.damage)
    # obj = loader.invoke("hero")
    # print(obj.weapon.damage)

if __name__ == "__main__":
    main()
    
