import os
import sys
import glob
from pathlib import Path

from version_parser import Version

import toml

repos=[]
release = {}
build = {}
requires={}
global_section={}

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
    if 'packages' in parse:
      update_section(parse, 'packages', release)

def update_build(parse):
    if 'dev-packages' in parse:
      update_section(parse, 'dev-packages', build)

def update_requires(parse):
    if 'requires' in parse:
      update_section(parse,'requires', requires)

def update_global(parse):
    for key in parse['global']:
        global_section[key] = parse['global'][key]

def default_pypi():
    repo = '''
[[source]]
url = "https://pypi.python.org/simple"
verify_ssl = true
name = "pypi"
'''
    
    return repo

def extra_pypi(address, port, name, verify):
    if verify:
        ssl = "true"
    else:
        ssl = "false"
    
    if port:
        address=f'https://{address}:{port}'
    else:
        address=f'https://{address}'

    return "\n".join(['[[[source]]',f'{address}/simple',f'verify_ssl = {ssl}',f'name = "{name}"'])
    
def load_pypi(repo_file):
    parse = None

    with open(repo_file) as f:
        parse = toml.load(f)

    if not parse or 'pypi' not in parse:
        return ""

    stripped_name = Path(os.path.basename(repo_file)).stem

    return extra_pypi(parse['pypi']['address'], parse['pypi']['port'], stripped_name,  parse['pypi']['verify'])
    
def print_pipfile():
    if global_section:
        print('[global]')

        for key in global_section:
            print(f'{key} = "{global_section[key]}"')

    print(default_pypi())

    if repos:
        for server in repos:
            print(server)

    if release:
        print('[packages]')

        for pkg in release:
            print(f'{pkg} = "{release[pkg]}"')

    if build:
        print('[dev-packages]')

        for pkg in build:
            print(f'{pkg} = "{build[pkg]}"')

    if requires:
        print('[requires]')

        for pkg in requires:
            print(f'{pkg} = "{requires[pkg]}"')

def exec():
    for module in sys.argv[1:]:
        for repo_file in glob.glob(f'{module}/*.pypi'):
            print(f'adding pypi server: {repo_file}')
            repos.append(load_pypi(repo_file))

        pipfile = f'{module}/Pipfile'

        if os.path.isfile(pipfile):
            with open(pipfile) as f:
                parse = toml.load(f)

                update_release(parse)
                update_build(parse)
                update_requires(parse)
        else:
            print(f'module spec: {module} does not resolve to {module}/Pipfile - skipping', 
                  file=sys.stderr)

    print_pipfile()

if __name__ == '__main__':
    exec()
