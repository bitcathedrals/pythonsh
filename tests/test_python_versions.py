import pytest

from pyutils.catpip import expand_version, get_python_feature, strip_pipfile_version_operators, get_pipfile_version, get_interpreter_version

def test_expand_version_minor():
    assert "1.2.0" == expand_version("1.2")

    assert "1.0.0" == expand_version("1")

def test_expand_version_pass():
    assert "1.2.0" == expand_version("1.2")

def get_version_feature():
    assert "1.2" == get_python_feature("1.2.3")
    assert "1.2" == get_python_feature("1.2")
    
def test_version_operator_strip():
    assert "1.2.3" == strip_pipfile_version_operators("==1.2.3")

    assert "1.2.3" == strip_pipfile_version_operators(">1.2.3")

def test_version_operator_strip_feature():
    assert "1.2" == strip_pipfile_version_operators(">=1.2")
    
def test_version_operator_strip_any():
    assert "*" == strip_pipfile_version_operators("*")

def test_get_version_feature():
    assert "1.2" == get_python_feature("1.2.3")
    
def test_version_operator_reformat():
    assert "~=1.2" == get_pipfile_version("~=1.2.3")
    assert "*" == get_pipfile_version("*")


def test_python_interpreter_version():
    assert "12.1.0" == get_interpreter_version("12.1.15")
    assert "12.1.0" == get_interpreter_version("12.1")
    assert "12.0.0" == get_interpreter_version("12")
