import os
import sys
from version_parser import Version

import toml

release = {}
build = {}
requires={}

def expand_version(version):
    if version == "*":
        return "9999999.0.0"
    
    fields = version.count('.')

    for i in range(fields + 1,3):
        version = version + '.0'

    return version

def update_section(parse, section, table):
    
    for pkg_name in parse[section]:

        if pkg_name in table:
            pkg_ver = parse[section][pkg_name]

            if table[pkg_name] == '*' or pkg_ver == '*':
                table[pkg_name] = '*'
                return

            if table[pkg_name] != pkg_ver:
                if Version(expand_version(table[pkg_name])) < Version(expand_version(pkg_ver)):
                    table[pkg_name] = pkg_ver
        else:
            table[pkg_name] = parse[section][pkg_name]

def update_release(parse):
    update_section(parse, 'packages', release)

def update_build(parse):
    update_section(parse, 'dev-packages', build)

def update_requires(parse):
    update_section(parse,'requires', requires)

def print_pipfile():    
    repo = '''
[[source]]
url = "https://pypi.python.org/simple"
verify_ssl = true
name = "pypi"
'''

    print(repo)

    print('[packages]')

    for pkg in release:
        print(f' {pkg} = "{release[pkg]}"')

    print('[dev-packages]')

    for pkg in build:
        print(f' {pkg} = "{build[pkg]}"')

    print('[requires]')

    for pkg in requires:
        print(f' {pkg} = "{requires[pkg]}"')

def exec():
    for module in sys.argv[1:]:
        pipfile = f'{module}/Pipfile'

        if os.path.isfile(pipfile):
            with open(pipfile) as f:
                parse = toml.load(f)

                update_release(parse)
                update_build(parse)
                update_requires(parse)
        else:
            print(f'module spec: {module} does not resolve to {module}/Pipfile - skipping')

    print_pipfile()

if __name__ == '__main__':
    exec()
