# Copyright © 2022 Yannick Gingras <ygingras@ygingras.net> and contributors

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

""" Kivy dialogs and pop-up forms """


import asynckivy as ak
from kivy.properties import ObjectProperty, BooleanProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.textinput import TextInput
from kivymd.uix.button import MDFlatButton
from kivymd.uix.dialog import MDDialog

from .dialogue import Action
from . import tender

class RevPopup(MDDialog):
    """ A popup notification. 
    
    Callers must provide a response_funct callback that will be called once the player 
    acknowledges the notification.
    """
    app = ObjectProperty(None)
    
    def __init__(self, response_funct, content_cls, *args, **kwargs):
        self.response_funct = response_funct
        self.ok_btn = MDFlatButton(text="OK", 
                                   on_release=self.dismiss)
        super().__init__(content_cls=content_cls, 
                         buttons=[self.ok_btn])
        
    def dismiss(self, *args):
        super().dismiss(*args)
        if self.response_funct:
            self.response_funct()


class RevForm(MDDialog):
    """ A popup form. 
    
    Subclasses must define the .is_valid() method and an inner content class that 
    contains the data widgets. .form_values() might need subclassing if the subclass 
    uses more than just TextInput widgets.
    
    Callers can either provide a response_funct callback that will receive the content 
    of the form once it passes validation or await .values_when_ready().
    """
    app = ObjectProperty(None)
    rejected = BooleanProperty(False)
    accepted = BooleanProperty(False)
    
    def __init__(self, response_funct, content_cls, *args, **kwargs):
        self.response_funct = response_funct
        self.cancel_btn = MDFlatButton(text="CANCEL", on_release=self.reject)
        self.ok_btn = MDFlatButton(text="OK", 
                                   on_release=self.try_accept, 
                                   disabled=True)
        super().__init__(content_cls=content_cls, 
                         buttons=[self.cancel_btn, self.ok_btn])
        
    def reset(self):
        """ Reset all value on the on form, making it ready for the next display. 
        
        Sub-classes should override this to clear the fields of the content_cls.
        """
        self.accepted = False
        self.rejected = False
        
    def form_values(self):
        """ Return the values contained in the form as a dictionary. 
        
        Form fields must have a `data_name` attribute to be captured; `data_name` is 
        used as the key in the returned dictionary. 
        """
        values = {}
        for wid in self.walk(restrict=True):
            if isinstance(wid, TextInput):
                if hasattr(wid, "data_name"):
                    values[wid.data_name] = wid.text
        return values
        
    async def values_when_ready(self):
        """ awaitable version of `.form_values()`
        
        When awaiting the form, you don't have to supply a `response_funct` to the 
        constructor and you don't have to call `.open()`, but you should `.reset()` in 
        between awaits on `.values_when_ready()` when you are recycling the form.

        None is returned if the form has been dismissed with the Cancel button or by 
        pressing Escape.
        """
        self.open()
        await ak.or_(ak.event(self, "accepted"), 
                     ak.event(self, "rejected"))
        if self.accepted:
            return self.form_values()
        else:
            return None
        
    def dismiss(self, *args):
        if not self.accepted:
            self.rejected = True
        super().dismiss(*args)

    def reject(self, *args, **kwargs):
        """ Dismiss the popup, ignoring the supplied data. """
        self.accepted = False
        self.rejected = True
        self.dismiss()
        
    def accept(self, *args, **kwargs):
        """ Dismiss the popup and consume the supplied data. """
        if self.response_funct:
            self.response_funct(**self.form_values())
        self.accepted = True
        self.dismiss()

    def try_accept(self, *args, **kwargs):
        """ Accept the form if data is valid, refuse with visual feedback otherwise. 
        """
        if self.is_valid():
            self.accept()

    def is_valid(self, *args, **kwargs): 
        """ See if the supplied data is ready for consumption. """
        raise NotImplementedError()
    
    def validate(self, *args, **kwargs):
        """ See if the data is ready for consumption and adjust the UI to reflect that. 
        
        Subclasses are encouraged to overload this method to provide a richer 
        experience.
        """
        self.ok_btn.disabled = not self.is_valid()

    def open(self, *args, **kwargs):
        """ Display the form. """
        self.reject()
        super().open(*args, **kwargs)


class HeroNameForm(RevForm):
    def __init__(self, response_funct=None, *args, **kwargs):
        cont = HeroNameFormContent()
        cont.ids.hero_name_field.bind(text=self.validate,
                                      on_text_validate=self.try_accept)
        super().__init__(response_funct, content_cls=cont)

    def is_valid(self, *args, **kwargs): 
        return bool(self.form_values()["hero_name"])


class HeroNameFormContent(BoxLayout):
    pass


class ConversationPopup(RevPopup):    
    def __init__(self, dialogue, response_funct=None, *args, **kwargs):
        self.content = ConversationPopupContent()
        self.dialogue = dialogue
        self.dialogue.start_lines()
        super().__init__(response_funct, content_cls=self.content)
        self.bind(on_dismiss=self.is_not_done)
        self.ok_btn.bind(on_release=self.try_advance)
        self.show_part()
        
    def is_not_done(self, *args):
        return not self.dialogue.is_last()

    def try_advance(self, *args):
        if not self.dialogue.is_last():
            self.dialogue.advance()
            self.show_part()
        else:
            self.dismiss()
        return True
        
    def show_part(self):
        if self.dialogue.is_last():
            self.ok_btn.text = "OK"
        else:
            self.ok_btn.text = "Next"
            
        part = self.dialogue.current()
        if isinstance(part, Action):
            res = tender.commands[part.name](*part.args)
            callback = self.dialogue.callback()
            if callback:
                callback(res)
        else:
            # TODO: append it to the history
            self.title = str(part.speaker)
            self.content.convo_label.text = part.text


class ConversationPopupContent(BoxLayout):
    convo_label = ObjectProperty(None)


class GameOverPopup(RevPopup):
    def __init__(self, response_funct, *args, **kwargs):
        super().__init__(response_funct, content_cls=None)
        self.ok_btn.bind(on_press=self.app.root.transition.center_on_button)


class ShowValuePopup(RevPopup):
    def __init__(self, value, response_funct=None, *args, **kwargs):
        content = ShowValuePopupContent()
        content.value_label.text = value
        super().__init__(response_funct, content_cls=content)


class ShowValuePopupContent(BoxLayout):
    value_label = ObjectProperty(None)
    
