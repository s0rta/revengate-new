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

""" Textual tagging. """

class Tag(str):
    """ An individual tag. """
    _registry = None
    def __init__(self, name, desc=None):
        super(Tag, self).__init__()
        if not name[0].isalpha():
            msg = f"Tag name must start with a letter, received {name}"
            raise ValueError(msg)
        self.name = name
        self.desc = desc

        self._register()

    def __hash__(self):
        return self.name.__hash__()
        
    def __eq__(self, tag):
        if isinstance(tag, Tag):
            return self.name == tag.name
        else:
            return super(Tag, self).__eq__(tag)

    def __repr__(self):
        if self.desc:
            return f"<{self.__class__.__name__}({self.name!r}, {self.desc!r})>"
        else:
            return f"<{self.__class__.__name__}({self.name!r})>"
            

    def _register(self):
        if self.__class__._registry is None:
            self.__class__._registry = TagRegistry()
        self.__class__._registry.add(self)

    @classmethod
    def is_registered(cls, tag):
        if cls._registry is None:
            return False
        return tag in cls._registry


def _find_tag(name, cls=Tag):
    if cls.is_registered(name):
        return cls(name)
    for sub in cls.__subclasses__():
        tag = _find_tag(name, sub)
        if tag:
            return tag

def t(tag_name):
    """ 
    Return the Tag instance for tag_name if it was pre-registered.
    Raise ValueError it tag_name was never registered.
    """
    tag = _find_tag(tag_name)
    if not tag:
        raise ValueError(f"{tag_name} is not a registered Tag")
    return tag


class TagRegistry(set):
    """ Keep track of all tags that were instanciated. """
    def __init__(self):
        super(TagRegistry, self).__init__()        


def _find_ns_class(ns, parent=Tag):
    if ns == parent.__name__:
        return parent
    for sub in parent.__subclasses__():
        cls = _find_ns_class(ns, sub)
        if cls:
            return cls


class TagBag(set):
    """ 
    A group of tags.

    namespace: Tag or one of it's subclasses.  Only instances of this class can 
               be added to the bag.  Can be a name or a class object. 
    Membership looking can be performed with tag instances or with tag name 
    strings.
    """
    def __init__(self, namespace=Tag, *members):
        super(TagBag, self).__init__()
        if isinstance(namespace, str):
            cls = _find_ns_class(namespace)
            if cls is None:       
                msg = f"{namespace} does not appear to be a subclass of Tag"
                raise ValueError(msg)
            else:
                namespace = cls
        self.namespace = namespace
        for m in members:
            self.add(m)

    def add(self, tag):
        if not self.namespace.is_registered(tag):
            msg = f"{tag} is not a registered instance of {self.namespace}"
            raise ValueError(msg)
        super(TagBag, self).add(tag)


class TagSlot:
    """ 
    A placeholder for a tag that enforces its namespace.

    namespace: see the doc for TagBag.

    This is using the descriptor protocol and should be set as a class 
    attribute.
    """
    def __init__(self, namespace=Tag):
        super(TagSlot, self).__init__()
        if isinstance(namespace, str):
            cls = _find_ns_class(namespace)
            if cls is None:       
                msg = f"{namespace} does not appear to be a subclass of Tag"
                raise ValueError(msg)
            else:
                namespace = cls
        self.namespace = namespace

    def __set_name__(self, owner, name):
        self.slot = '_' + name

    def __get__(self, obj, objtype=None):
        return getattr(obj, self.slot)

    def __set__(self, obj, tag):
        if not self.namespace.is_registered(tag):
            msg = f"{tag} is not a registered instance of {self.namespace}"
            raise ValueError(msg)
        setattr(obj, self.slot, tag)

