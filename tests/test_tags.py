
from pytest import raises
from revengate import tags


class BoringTag(tags.Tag): pass
class OtherTag(tags.Tag): pass


def test_t_must_be_registered():
    """ Test that t() raises for tags that were not pre-registered. """
    with raises(ValueError):
        tags.t("new-tag")
        

def test_t_uses_registry():
    """ Test that t() returns the instance stored in the registry. """
    tag = tags.Tag("some-tag", desc="This tag is only for test purposes.")
    assert tags.t("#some-tag") is tag


def test_no_ns_leak():
    """ Test that tags are contained within the namespace or their class hierarchy. """
    _ = BoringTag("my-tag")
    assert "my-tag" in set(BoringTag.iter_tags())
    assert "my-tag" not in set(OtherTag.iter_tags())
