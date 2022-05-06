
import pytest

from revengate.maps import Map, Builder
from revengate.actors import Actor

@pytest.fixture
def init_map():
    map = Map()
    builder = Builder(map)
    builder.init(100, 30)
    builder.room((5, 5), (20, 20))

    me = Actor(50, 50, 50, 50)
    map.place(me, (6, 6))
    other = Actor(55, 55, 55, 55)
    map.place(other, (5, 7))
    return map, me, other


def is_diag(coord):
    x, y = coord
    return x == y


def test_vis_scope_pred(init_map):
    map, me, _ = init_map
    scope = map.visible_scope(me, 2, pred=is_diag)
    for x, y in scope:
        assert x == y


def test_vis_scope_on_actors(init_map):
    map, me, other = init_map
    scope = map.visible_scope(me, 2, pred=Actor)
    assert {actor for pos, actor in scope.actors} == {me, other}
