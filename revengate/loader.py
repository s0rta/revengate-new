#! /usr/bin/env python3

# Copyright © 2020–2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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
- content: a key describing the sub-loader to invoke to decode the data into Python 
  instances.

See the documentation of various sub-classes of SubLoader for the various data 
representations that are supported. 

"""

import os
import sys
import json
import inspect
from pprint import pprint
from itertools import chain
from logging import debug
import tomlkit

# classes loaders can instantiate; this could be factored out
from . import tags, tender
from .tags import Tag, t
from .randutils import rng
from .strategies import Strategy
from .items import Item
from .effects import EffectVector, Effect
from .actors import Actor
from .dialogue import Dialogue, Line, Action, DialogueTag, SpeakerTag, CommandTag
from .sentiment import SentimentChart


TOP_SECTION = "RevengateFile"
FORMAT = 0


DATA_DIR = os.path.join(os.path.dirname(__file__), "data")


def data_path(fname):
    """ 
    Return a fully qualified path for fname withtout checking if fname is actually in 
    the data directory. 
    """
    return os.path.join(DATA_DIR, fname)


def data_file(fname):
    """ 
    Return an open file in reading for fname. If fname is a not in the local directory, 
    we try to find it in the DATA_DIR.
    
    ValueError is raised if the file can't be found.
    """
    path = fname
    if not os.path.isfile(path):
        path = data_path(fname)
    if not os.path.isfile(path):
        raise ValueError(f"Can't find {fname}")
    return open(path, "rt")


class Template:
    """ Template are recipes for creating entities.  
    
    Resulting entities can be fully initialized or only partialy so. Invoking 
    a template to produce an instance must be done by a factory, typically a 
    SubLoader.
    """

    def __init__(self, name, parent=None, fields=None):
        super(Template, self).__init__()
        # Templates must know their name: it simplifies the inheritance resolution
        self.name = name  
        self.parent = parent
        self.fields = fields or {}


class TopLevelLoader:
    """ Initial file loader: do some file validation, then invoke the 
    appropriate sub-loader(s) based on content type. """

    def __init__(self):
        # We keep the sub-loader used for each file. Template invocation and 
        # instance lookup is defered to them.
        self.master_file = None
        self.sub_loaders = {}  # content_key -> instance
        
    def load(self, fp):
        serializer = None
        if fp.name:
            base, ext = os.path.splitext(fp.name)
            if self.master_file is None:
                self.master_file = fp.name
            if ext in (".toml", ".tml"):
                serializer = tomlkit
            elif ext == ".json":
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
                    self.sub_loaders[content_type] = cls(self)
                    break
            else:
                # we got to the end of the loop without finding a sub-loader
                raise ValueError("Could not find a SubLoader for " 
                                 f"{content_type}")
        loader = self.sub_loaders[content_type]
        return loader.decode(root_record)

    def invoke(self, template_name, **kwargs):
        """ Create a fresh instance based on `template_name`. 
        
        Values in kwargs overwrite the ones specified in the template. 
        """
        for loader in self.sub_loaders.values():
            obj = loader.invoke(template_name, **kwargs)
            if obj:
                return obj
        raise ValueError(f"Could not find a sub-loader to handle {template_name}.")
        
    def get_instance(self, name):
        """ Return the existing object instance registered as `name`. """
        for loader in self.sub_loaders.values():
            obj = loader.get_instance(name)
            if obj:
                return obj
        raise ValueError("Could not find a sub-loader with an instance "
                         f"registered as {name}.")

    def get_template(self, name):
        """ Return template `name` without invoking it. """
        for loader in self.sub_loaders.values():
            tmpl = loader.get_template(name)
            if tmpl:
                return tmpl
        raise ValueError("Could not find a sub-loader with a template "
                         f"registered as {name}.")
    
    def templates(self):
        """ Return all known template names. """
        return chain(*(loader.templates() for loader in self.sub_loaders.values()))

    def instances(self):
        """ Return all known instance names. """
        return chain(*(loader.instances() for loader in self.sub_loaders.values()))


class SubLoader:
    """ Base class for inner content loaders. 
    
    Content discovery is based on the `content_key` class attribute. """
    
    content_key = None

    def __init__(self, top_loader):
        self.top_loader = top_loader

    def decode(self, record):
        raise NotImplementedError()

    def invoke(self, template_name, **kwargs):
        """ Create a fresh instance based on `template_name`. 
        
        Values in kwargs overwrite the ones specified in the template. 
        
        sub-classes should return None if they can't handle the request.
        """
        raise NotImplementedError()

    def templates(self):
        return ()
            
    def get_template(self, name):
        return None
    
    def get_instance(self, name):
        """ Return the existing object instance registered as `name`. 

        sub-classes should return None if they can't handle the request.
        """
        raise NotImplementedError()

    def instances(self):
        return ()


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

    def __init__(self, top_loader):
        super().__init__(top_loader)

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

    def invoke(self, template_name, **kwargs):
        return None
        
    def get_instance(self, name):
        return None


class DialogueLoader(SubLoader):
    """ Load dialogues. 
    
    The 'RevengateFile' section must have 'speakers' and 'actions' attributes: lists of 
    strings.
    
    The file is composed of multiple dialogues, each as subsections of [dialogues], each 
    with a unique name. A dialogue must define a 'script' attribute: a multi-line 
    string in the following format:
    - comments start with '# ' and continue until the end of the line;
    - tags start with '#' and are immediately followed by alphanumerics, "_" or "-";
    - top level tags are followed by ':', everything until the next top level tag and 
      the end of the documents is an argument to the top level tag;
    - arguments can be separated by pipes or new lines ("|" or "\n");
    - for speaker tags, each non-tag argument becomes a speech line for that speaker;
    - for action tags, each non-tag is passed verbatim to the target function;
    - only action tags are allowed as arguments, they are called *after* the preceeding 
      element is displayed or selected, depending if the preceeding element is part of a 
      sequence of speech or part of a choice;
    - if an action tag is the first argument of a top level action, it will be called 
      with the return value of the top level action.
      
    Syntactic legaleese aside, it's quite simple: start with a speaker tag, type all the 
    lines for that speaker (either as separate lines or separated by |). Move to the 
    next speaker with a new speaker tag on a new line. If actions need to happen because 
    a line of speech has consequences on the game world, add an action tag after that 
    line of speech.

    
    TODO include a few examples
    
    """
    
    content_key = "dialogues"
    COMMENTS = ["# ", "#\t", "#\n"]

    def __init__(self, top_loader):
        super().__init__(top_loader)
        self.dialogues = {}
        self._speakers = {}
        self._actions = {}

    def _strip_comments(self, line):
        for style in self.COMMENTS:
            cmt_pos = line.find(style)
            if cmt_pos >= 0:
                line = line[:cmt_pos]
        # Typically the '\n' has already been stripped, but we also have to check for 
        # this:
        if line == "#":
            line = ""
        return line

    def _decode_one(self, name, record):
        tag = DialogueTag(name)
        dia = Dialogue(tag)
        lines = record["script"].split("\n")
        lines = [self._strip_comments(l) for l in lines]
        
        cur_elem = None
        cur_args = []

        def finalize_elem():
            # This looks a bit like a mess because one speaker tag generates many speech 
            # lines while one action tag is only one action. Keeping that in mind, what 
            # follows is reasonably straight forward.
            nonlocal cur_elem, cur_args
            
            if cur_elem is None and len(cur_args) == 0:
                return
            elif cur_elem is None:
                raise ValueError("Malformed file: arguments without a top level tag.")
            
            if isinstance(cur_elem, SpeakerTag):
                # all non-tag arguments after a speaker tag are lines of dialogue for 
                # that speaker
                for arg in cur_args:
                    if arg.startswith("#"):
                        tag = self._decode_tag(arg)
                        if dia.elems:
                            dia.elems.after_ftag = tag
                        else:
                            dia.elems.append(Action(tag))
                    else:
                        dia.elems.append(Line(text=arg, speaker=cur_elem))
            else:
                # non-tag arguments after an action tag are passed verbatim to the 
                # target function
                args = []
                action = Action(name=cur_elem, args=args)
                for arg in cur_args:
                    arg = arg.strip()
                    if arg.startswith("#"):
                        arg = self._decode_tag(arg)
                        if args:
                            args[-1].after_ftag = arg
                        else:
                            action.after_ftag = arg
                    else:
                        args.append(Line(arg))
                    
                dia.elems.append(action)
            
            # reset for next parsing
            cur_elem = None
            cur_args = []

        for line in lines:
            line = line.strip()
            if len(line) == 0 or line.isspace():
                continue
            if line.startswith("#") and line[1].isalpha():
                # we have a tag!
                tag, line = line.split(':', 1)
                tag = self._decode_tag(tag)
                finalize_elem()
                cur_elem = tag
            cur_args += [part.strip() for part in line.split("|")]
        finalize_elem()
        return dia
    
    def _decode_tag(self, tag):
        tag = tag.strip("#:")
        if tag in self._speakers or tag in self._actions:
            return t(tag)  # the tag registry remembers what namespace it belongs to
        else:
            raise ValueError(f"Not a registered action or speakers: {tag!r}")

    def decode(self, record):
        for tag in record[TOP_SECTION]["speakers"]:
            self._speakers[tag] = SpeakerTag(tag)
        for tag in record[TOP_SECTION]["actions"]:
            self._actions[tag] = CommandTag(tag)

        dias = {}
        for name, subrec in record["dialogues"].items():
            dias[name] = self._decode_one(name, subrec)
        self.dialogues.update(dias)
        return dias
        
    def invoke(self, template_name, **kwargs):
        # We can't easily take advantage of the full power of TemplatizedObjects without 
        # deriving from their loader and making the Dialogue DSL compatible with it, so 
        # we return a fresh clone of the pristine instance of Dialogue instead.
        if template_name in self.dialogues:
            return self.dialogues[template_name].clone()
        return None
        
    def get_instance(self, name):
        if name in self.dialogues:
            return self.dialogues[name]
        return None
    
    def instances(self):
        return self.dialogues.keys()


class TemplatizedObjectsLoader(SubLoader):
    """ Factory class for creating templatized object instances.
    
    Object templates specify some or all the fields of an object with the values that 
    they should be initialized to. Templates can inherit some of their values from 
    parent templates and they can apply basic transforms to the parent values. Values 
    can also be initialized with random numbers inside the specified range.

    Two sections must be present: 'instances' and 'templates'. Both are name->definition 
    mappings. Instances are initialized when calling decode() on a file. Templates must 
    be invoked by calling invoke() to create a new instance.
    
    Special fields:
    _class: the class to instantiate
    _parent: another template that this template inherits from

    field names can be prefixed by the following for special action:
    '+': add value to the value of the parent template (appends with lists)
    '-': subtract value to the value of the parent (not implemented for lists)
    '!': random value, pass the max int or a [min, max] list for a range

    values can be prefixed by the following for special actions:
    '*': invoke a sub-template by name
    '@': return an existing instance by name
    '#': invoke a tag by name, similar to tags.t()

    Fields that are named in the constructor of an object's Python class are set at 
    creation time. All the other fields are set after the object has been created.
    
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
    
    # Templates and instances can only be for those classes and their sub-classes. It 
    # would make sens to factor this out at some point. This list is processed during 
    # the instantiating of the sub-loader and therefore all changes to it must be done 
    # before the first file is loaded.
    loadable_classes = [Tag, Item, EffectVector, Effect, Strategy, Actor, 
                        SentimentChart]

    def __init__(self, top_loader):
        super().__init__(top_loader)
        
        self._class_map = {}  # name -> class object mapping
        
        # for by-name invocations
        self._instances = {} 
        self._templates = {}
        
        for cls in self.loadable_classes:
            self._map_class_tree(cls)
        
    def _map_class_tree(self, cls):
        """ Add `cls` and all its subclasses to the registry of loadable object types. 
        """
        self._class_map[cls.__name__] = cls
        for sub in cls.__subclasses__():
            self._map_class_tree(sub)

    def _expand_one(self, field):
        """ Expand invocations (tags, templates, refs), and generators in field.
        
        Return the field unmodified if there are no references. """
        if callable(field):
            return field()
        elif isinstance(field, str) and field.startswith("#"):  # tag
            return tags.t(field[1:])
        elif isinstance(field, str) and field.startswith("@"):  # instance ref
            return self.get_instance(field[1:])
        elif isinstance(field, str) and field.startswith("*"):  # sub-template
            return self.invoke(field[1:])
        return field
    
    def _expand_many(self, field):
        """ Expand a compound field recursively. """
        if isinstance(field, list):
            return [self._expand_many(s) for s in field]
        if isinstance(field, list):
            return tuple(self._expand_many(s) for s in field)
        if isinstance(field, dict):
            return {self._expand_many(k): self._expand_many(v) 
                    for k, v in field.items()}
        return self._expand_one(field)

    def _instantiate(self, cls_name, fields, record_name=None):
        """ Create an instance of cls_name with all the fields specified.
        
        Fields with names that match argument names in the constructor signature are 
        passed at creation time, the other ones are set as attributes after creation.
        
        `record_name`: uses as `name` unless `name` is explicitly specified.
        """
        cls = self._class_map[cls_name]
        # apply fields references
        for k, v in list(fields.items()):
            if isinstance(v, str) or callable(v):
                fields[k] = self._expand_one(v)
            if isinstance(v, (list, tuple, dict)):
                fields[k] = self._expand_many(v)
        # find which fields are constructor-friendly
        init_args = {}
        params = inspect.signature(cls).parameters
        for arg in params:
            if arg in fields:
                init_args[arg] = fields.pop(arg)
                
        # 'name' is a special case: it's often the same as the Template name
        if "name" in params and "name" not in init_args:
            if record_name:
                init_args["name"] = record_name
        
        debug(f"instantiating {cls_name} with {init_args}")
        obj = cls(**init_args)
        # set the other fields after creation
        for attr in fields:
            setattr(obj, attr, fields[attr])
        if hasattr(obj, "engine") and tender.engine:
            obj.engine = tender.engine
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
    
        obj = self._instantiate(rec.pop("_class"), rec, record_name=name)
        self._instances[name] = obj
        return obj

    def _stack_str(self, stack):
        """ Return a printable summary of a template stack. """
        return "->".join([t.name for t in stack])
    
    def decode(self, rec):
        # only instances and templates for the current file are returned
        instances = {}
        for name, subrec in rec["instances"].items():
            # transform mappings specific to the file format into a plain dict
            subrec = dict(subrec)  
            obj = self._decode_instance(name, subrec)
            instances[name] = obj
        templates = {}
        for name, subrec in rec["templates"].items():
            # transform mappings specific to the file format into a plain dict
            subrec = dict(subrec)
            obj = self._decode_template(name, subrec)
            templates[name] = obj
        return dict(instances=instances, templates=templates)
        
    def _random_field(self, val):
        """ Convert val into a random generator.
        
        val: either max or a [min, max] list.
        The generator is called at invocation time.
        """
        if isinstance(val, int):
            return lambda: rng.randrange(val+1)
        elif isinstance(val, list):
            min, max = val
            return lambda: rng.randrange(min, max+1)
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

    def invoke(self, template, **kwargs):
        """ Instantiate an object based on a template.  
        
        The template can be a name or a Template instance. 
        """
        if not isinstance(template, Template):
            if template not in self._templates:
                return None
            template = self._templates[template]
        debug(f"invoking {template.name}")
        
        # resolution is two steps: 
        # 1) find all the parents
        # 2) populate all the fields starting at the oldest ancestor
        oname = template.name  # the original name before we resolve inheritance
        seen = set()  # to prevent infinite loops
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
            tfields = dict(t.fields)  # we don't want to modify the original
            # manually apply the fields with special overrides: +, -, ...
            for prefix, action in [("!", self._random_field)]:  # single actions
                keys = [k for k in tfields if k.startswith(prefix)]
                for k in keys:
                    v = tfields.pop(k)
                    k = k[1:]
                    fields[k] = action(v)
            for prefix, action in [("+", self._add_to_field), 
                                   ("-", self._sub_from_field)]:  # transforms
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
        fields.update(kwargs)  # the invoke() kwargs override everything
        return self._instantiate(fields.pop("_class"), fields, oname)

    def get_instance(self, name):
        return self._instances.get(name)

    def get_template(self, name):
        return self._templates.get(name)

    def templates(self):
        return self._templates.keys()
    
    def instances(self):
        return self._instances.keys()
    
