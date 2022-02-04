# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net>

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

""" Conversations between actors. """

from .tags import Tag, t

import functools
import inspect


DIA_1 = [
    ["#salapou", ["What a great pleasure to see you here {hero}", 
                    "Please accept this token of hispotality",
                    "#add-potion-to-inventory"]]
]

# #salapou: – What a great pleasure to see you here {hero}
#    - Please accept this token of hospitality
#    #add-potion-to-inventory

DIA_2 = [
    ["#salapou", "You have no power over me!"],
    ["#bob", "That is true, but I have power over this circus business of yours."],
    ["#salapou", "We shall see about that!"]
]

DIA_3 = [
    ["#salapou", "This is my final offer. What do you say?"], 
    ["#prompt", [["Accept", "#agree-with-salapou"], 
                 ["Decline", "#fight-salapou"]]]
]

DIA_4 = [
    ["#salapou", "This is my final offer. What do you say?"], 
    ["#yes-no-prompt", ["#agree-with-salapou", "#fight-salapou"]]
]

DIA_5 = [
    ["#salapou", "This is my final offer. What do you say?"], 
    ["#speach-choice", 
     [["You are right, let's be allies.", "#agree-with-salapou"], 
      ["Die, you megalomaniac!", "#fight-salapou"]]]
]


class UI:
    """ 
    Mock class for the general UI that should be designed in order to run the game on 
    both terminal and graphical interfaces.
    """
    
    def __init__(self, engine=None):
        # FIXME: late initialisation of the engine must also re-init the ActionMap
        self.engine = engine
        self.action_map = ActionMap(engine, self)


class TextUI(UI):
    def show_dia(self, dia):
        for part in dia.seq:
            if isinstance(part, Action):
                result = self.action_map.call(part.name, *part.args)
                if part.after_ftag:
                    self.action_map.call(part.after_ftag, result)
                    
            else:
                print(part)
                if part.after_ftag:
                    self.action_map.call(part.after_ftag)
                input("Press ENTER to continue...")
            
    def prompt(self, *options):
        opt_map = dict(enumerate(options, 1))
        choice = None
        while choice not in opt_map:
            print("Choose one...")
            for num, text in opt_map.items():
                print(f"{num}: {text}")
            choice = input()
            if not choice or not choice.isdigit():
                choice = None
                print(f"Your response must be a number, not {choice!r}.")
            else:
                choice = int(choice)
                if choice not in opt_map:
                    print(f"{choice} is not a valid option.")
        if getattr(opt_map[choice], "after_ftag"):
            self.action_map.call(opt_map[choice].after_ftag)
        return choice


class Speaker(Tag):
    pass


class ActionTag(Tag):
    pass


class Line:
    """ A line of dialogue. 
    
    If `after_ftag` is provided, it is called without arguments (except the global ones 
    described in the ActionMap class) immediately after the line is displayed. The 
    after_ftag is called everytime the line is spoked.
    """
    
    def __init__(self, text, speaker=None, after_ftag=None):
        self.text = text
        self.speaker = speaker
        self.after_ftag = after_ftag
        
    def __str__(self):
        if self.speaker:
            return f'{self.speaker}: "{self.text}"'
        else:
            return self.text


class Action:
    """ An event taking place sometime during the course of a dialogue. 
    
    If `after_ftag` is provided, it is called with the result of the current action 
    immediately after its execution. The other global arguments described in ActionMap 
    are supported.
    """

    def __init__(self, name, args, after_ftag=None):
        self.name = name
        self.args = args
        self.after_ftag = after_ftag


class Dialogue:
    def __init__(self, key):
        self.key = key
        self.seq = []


class ActionMap:
    """ Mapping between action names and functions 
    
    Action funtions can be explicitely registered or be implicitely defined as instance 
    methods of ActionMap or one of it's subclasses.
    
    Actions functions will receive "engine" and "ui" as their first two paramers if they 
    declare then in their signature.
    """

    def __init__(self, engine=None, ui=None):
        self.engine = engine
        self.ui = ui
        self._actions = {}
    
    def __contains__(self, action):
        return action in self._actions or hasattr(self, action)
        
    def register(self, funct, name=None):
        # discover the name if not provided
        if name is None:
            if not hasattr(funct, "__name__") or "lambda" in funct.__name__:
                raise ValueError("Can't register function: name not provided "
                                 "and funct is not a named function.")
            name = funct.__name__
        self._actions[name] = funct
        
    def _apply_global_args(self, funct):
        """ 
        Return a function with partial binding of arguments that we already know about 
        and do not receive from the caller when the action is later called.
        """
        sig = inspect.signature(funct)
        params = sig.parameters
        kwargs = {}
        for key in ["engine", "ui"]:
            if key in params:
                kwargs[key] = getattr(self, key)
        if kwargs:
            funct = functools.partial(funct, **kwargs)
        return funct

    def call(self, action, *args):
        if action in self._actions:
            funct = self._actions[action]
        elif hasattr(self, action):
            funct = getattr(self, action)
        else:
            raise ValueError(f"Action {action} is not registered or defined "
                             "as a class method.")
        funct = self._apply_global_args(funct)
        return funct(*args)

    def prompt(self, *options):
        """ Prompt the player to make a choice. """
        return self.ui.prompt(*options)
    
    def yes_no_prompt(self):
        return self.promp("Yes", "No")
        

def main():
    # TODO: speaker lookup
    speakers = [Speaker("bob"), Speaker("salapou"), Speaker("hero")]
    
    ui = TextUI()
    ui.action_map.register(lambda: print("done with the rambling"), 
                           "log-end-of-speach")
    ui.action_map.register(lambda resp: print(f"done with the selection: {resp}"), 
                           "log-selection")
    
    dia = Dialogue("one")
    speaker, texts = DIA_1[0]
    for text in texts:
        dia.seq.append(Line(text, speaker))
    dia.seq[-1].after_ftag = "log-end-of-speach"
    options = [Line("OK!"), 
               Line("Maybe...", after_ftag="log-end-of-speach"), 
               Line("No way!")]
    dia.seq.append(Action("prompt", options))

    ui.show_dia(dia)


if __name__ == "__main__":
    main()
