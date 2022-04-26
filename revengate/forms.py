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


from kivy.properties import ObjectProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.textinput import TextInput
from kivymd.uix.button import MDFlatButton
from kivymd.uix.dialog import MDDialog


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
    
    Subclasses must define the is_valid() method and an inner content class that 
    contains the data widgets.
    
    Callers must provide a response_funct callback that will receive the content of the 
    form once it passes validation.
    """
    app = ObjectProperty(None)
    
    def __init__(self, response_funct, content_cls, *args, **kwargs):
        self.response_funct = response_funct
        self.cancel_btn = MDFlatButton(text="CANCEL", on_release=self.dismiss)
        self.ok_btn = MDFlatButton(text="OK", 
                                   on_release=self.try_accept, 
                                   disabled=True)
        super().__init__(content_cls=content_cls, 
                         buttons=[self.cancel_btn, self.ok_btn])
        
    def form_values(self):
        """ Return the values contained in the form as a dictionnary. 
        
        Form fields must have a `data_name` attribute to be captired; `data_name` is 
        used as the key in the returned dictionnary. 
        """
        values = {}
        for wid in self.walk(restrict=True):
            if isinstance(wid, TextInput):
                if hasattr(wid, "data_name"):
                    values[wid.data_name] = wid.text
        return values
        
    def accept(self, *args, **kwargs):
        """ Dimiss the popup and consume the supplied data. """
        if self.response_funct:
            self.response_funct(**self.form_values())
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


class HeroNameForm(RevForm):
    def __init__(self, response_funct, *args, **kwargs):
        cont = HeroNameFormContent()
        cont.ids.hero_name_field.bind(text=self.validate,
                                      on_text_validate=self.try_accept)
        super().__init__(response_funct, content_cls=cont)

    def is_valid(self, *args, **kwargs): 
        return bool(self.form_values()["hero_name"])


class HeroNameFormContent(BoxLayout):
    pass


class ConversationPopup(RevForm):
    def __init__(self, response_funct, *args, **kwargs):
        cont = ConversationPopupContent()
        super().__init__(response_funct, content_cls=cont)


class ConversationPopupContent(BoxLayout):
    pass


class GameOverPopup(RevPopup):
    def __init__(self, response_funct, *args, **kwargs):
        super().__init__(response_funct, content_cls=None)
        self.ok_btn.bind(on_press=self.app.root.transition.center_on_button)
