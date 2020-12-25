#! /usr/bin/env python3

# Copyright © 2020 Yannick Gingras <ygingras@ygingras.net>

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

""" Object creation from json data. """

import sys
import json
import inspect
from random import randrange
from pprint import pprint

from . import tags
from .tags import Tag
from .weapons import HealthVector, Effect
from .actors import Actor

# Special fields:
# &class: the class to instanciate
# &template: a template name that can be invoked later
# &parent: another template that can this template derives from

# If no template name is specified, this is an instance, which we create on 
# the spot. 

# field names can be prefixed by the following for special action:
# '+': add value to the value of the parent template (works with lists)
# '-': subtrack value to the value of the parent (not implemented for lists)
# '!': random value, pass the max int or a [min, max] list

# values can be prefixed by the following for special actions:
# '*': invoke a sub-template by name
# '#': invoke a tag by name, similar to tags.t()

class Template:
    """ Template are recipes for creating entities.  
    
    Resulting entities can be fully initialized or only partialy so. 
    """
    def __init__(self, name, parent=None, fields=None):
        super(Template, self).__init__()
        self.name = name
        self.parent = parent
        self.fields = fields or {}

class Loader:
    """ Factory class for creating instances from json data. """
    def __init__(self):
        super(Loader, self).__init__()
        self._class_map = {} # name -> class object mapping
        self._templates = {} # for by-name invokation
        for cls in [Tag, HealthVector, Effect, Actor]:
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
        if isinstance(field, str) and field.startswith("#"): # tag
            return tags.t(field[1:])
        if isinstance(field, str) and field.startswith("*"): # sub-template
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
        return obj
  
    def _decode_one(self, rec):
        """ Convert a single record to either a template or an instance. """
        if "&template" in rec:
            name = rec.pop("&template")
            parent = rec.pop("&parent", None)
            obj = Template(name, parent, rec)
            self._templates[name] = obj
            return obj
        if "&parent" in rec:
            raise ValueError(f"Parent specified without a template name: {rec}")
    
        obj = self._instanciate(rec.pop("&class"), rec)

        return obj

    def _stack_str(self, stack):
        """ Return a printable summary of a template stack. """
        return "->".join([t.name for t in stack])
  
    def load(self, fp):
        return self.loads(fp.read())
        
    def loads(self, data):
        recs = json.loads(data)
        if isinstance(recs, dict):
            return self._decode_one(recs)
        else:
            return [self._decode_one(r) for r in recs]

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
        return self._instanciate(fields.pop("&class"), fields, oname)

def main():
    loader = Loader()
    objs = loader.load(open(sys.argv[1], "r"))
    pprint(list(objs))
    obj = loader.invoke("hero")
    print(obj.weapon.damage)

if __name__ == "__main__":
    main()
    
