import pytest

from pyutils.catpip import get_python_feature, strip_pipfile_version_operators, get_pipfile_version

def get_version_feature():
    assert "1.2" == get_python_feature("1.2.3")
    
def test_version_operator_strip():
    assert "1.2.3" == strip_pipfile_version_operators("==1.2.3")

    assert "1.2.3" == strip_pipfile_version_operators(">1.2.3")

def test_get_version_feature():
    assert "1.2" == get_python_feature("1.2.3")
    
def test_version_operator_reformat():
    assert "~=1.2" == get_pipfile_version("~=1.2.3")


