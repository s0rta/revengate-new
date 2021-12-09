# Copyright © 2021 Yannick Gingras <ygingras@ygingras.net>

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

""" 
Word salad generators: like Lorem Ipsum, but sounds like modern languages. 
"""

from os import path
import re
import random
from revengate import randutils

DATA_DIR = path.join(path.dirname(__file__), "data/")
FILE_PAT = "nonsense-{lang}.txt"
PARA_PAT = re.compile(r"\n+\s*")
PUNCT_PAT = re.compile(r"(.*?)([!?.]+)\s+")

class WordSaladGenerator:
    """ Generate a word salad. """
    sentence_len = (3, 12)

    def __init__(self, lang="en"):
        self.data_file = path.join(DATA_DIR, FILE_PAT.format(lang=lang))
        self.words = [w.strip() for w in open(self.data_file, "r")]

    def sentence(self, punct=".", nb_words=None):
        """ Return a nonsense sentence. """

        if nb_words is None:
            nb_words = randutils.rint(self.sentence_len)
        words = random.choices(self.words, k=nb_words)
        words[0] = words[0].title()
        words[-1] = words[-1] + punct
        return " ".join(words)
    
    def convert(self, text):
        """ Convert text into nonsense with the same number or words and 
        sentences. """
        salad = []
        
        paras = PARA_PAT.split(text)
        for para in paras:
            cur_nonsense = []
            for sentence, punct in PUNCT_PAT.findall(para):
                nb_words = len(sentence.split())
                if nb_words > 0:
                    cur_nonsense.append(self.sentence(punct, nb_words))
            if cur_nonsense:
                salad.append(" ".join(cur_nonsense))
        return "\n\n".join(salad)
    

def main():
    text = """This is a test. A small test, but a test nontheless. It shall show two things: 1) we can generate text; 2) it kind of looks good.
    
    Of course, it will also handle paragraphs. And it will handle them well! 
    """
    for lang in ["fr", "en", "de"]:
        print(f"== {lang} ==")
        gen = WordSaladGenerator(lang)
        print(gen.convert(text))


if __name__ == "__main__":
    main()
    
