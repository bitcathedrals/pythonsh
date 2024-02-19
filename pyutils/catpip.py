import os
import sys
import glob
from pathlib import Path
import re
from collections import namedtuple

from version_parser import Version

package_spec = namedtuple('package_spec', ['name','version', 'index'])

default_server = 'pypi'

import toml

repos=[]
release = {}
build = {}
requires={}
global_section={}

open_brace = "{"
close_brace = "}"

def expand_version(version):
    if version == "*":
        return "9999999.0.0"

    fields = version.count('.')

    for i in range(fields + 1,3):
        version = version + '.0'

    return version

def update_packages(filename, parse, section, table):
    
    for pkg_name in parse[section]:
        pkg_spec = parse[section][pkg_name]

        pkg_ver = None
        pkg_server = default_server

        if isinstance(pkg_spec, dict):
            pkg_ver = pkg_spec['version']
            pkg_server = pkg_spec['index']
        else:
            pkg_ver = pkg_spec

        if pkg_name in table:
            if table[pkg_name].version == '*' or pkg_ver == '*':
                pkg_ver = '*'
                print(f'package {pkg_name} version "*" is latest: taking the latest version',
                      file=sys.stderr)
            else:
                if table[pkg_name].version != pkg_ver:
                    if Version(expand_version(table[pkg_name].version)) > Version(expand_version(pkg_ver)):
                        print(f'current {pkg_name} version {table[pkg_name].version} is newer than {filename}:{pkg_ver} - taking the latest version', 
                              file=sys.stderr)
                        pkg_ver = table[pkg_name].version
        
        table[pkg_name] = package_spec(name=pkg_name, version=pkg_ver, index=pkg_server)

def update_variables(filename, parse, section, table):
    
    for var_name in parse[section]:
        version = parse[section][var_name]

        if var_name in table:   
            if table[var_name] != version:
                if Version(expand_version(table[var_name])) > Version(expand_version(version)):
                    print(f'current {var_name} version {table[var_name]} is newer than {filename}:{var_name} - taking the latest version', 
                            file=sys.stderr)
                    
                    version = table[var_name]

        table[var_name] = version

def update_release(filename, parse):
    if 'packages' in parse:
      update_packages(filename, parse, 'packages', release)

def update_build(filename, parse):
    if 'dev-packages' in parse:
      update_packages(filename, parse, 'dev-packages', build)

def get_python_version():
    pythonsh = open('python.sh', 'r')
    
    for line in pythonsh:
        line = line.strip()
        
        if line.startswith('PYTHON_VERSION'):
            v = line.split('=')[1].strip()

            v = v.replace('"', '')
            v = v.replace("'", '')

            return v

    return None

def get_python_feature(spec):
    v = spec.split('.')[0:2]
    
    return '.'.join(v)

def strip_pipfile_version_operators(spec):
     return re.findall(r'\d+\.\d+\.\d+', spec)[0]

def get_python_bug_fixes(spec):
    v = strip_pipfile_version_operators(spec)

    v = get_python_feature(v) + '.0'

    return

def get_pipfile_version(spec):
    return '~=' + get_python_feature(strip_pipfile_version_operators(spec))

def update_requires(filename, parse):
    pythonsh_version = expand_version(get_python_version())

    if 'requires' in parse:
        if 'python_version' in parse['requires']:
            requires_version = expand_version(parse['requires']['python_version'])

            if pythonsh_version != requires_version:
                if Version(pythonsh_version) > Version(requires_version):
                    print(f'taking current PYTHON_VERSION: {pythonsh_version} over Pipfile {requires_version}', 
                            file=sys.stderr)
                    parse['requires']['python_version'] = get_python_feature(pythonsh_version)
                else:   
                    parse['requires']['python_version'] = get_python_feature(requires_version)
        else:
            parse['requires']['python_version'] = get_python_feature(pythonsh_version)
    else:
        parse['requires'] = {'python_version': get_python_feature(pythonsh_version)}

    update_variables(filename, parse,'requires', requires)

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
    protocol = 'https'

    if verify:
        ssl = "true"
    else:
        ssl = "false"
        protocol = 'http'

    if port:
        address=f'{protocol}://{address}:{port}'
    else:
        address=f'{protocol}://{address}'

    return "\n".join(['[[source]]',f'url = "{address}/simple"',f'verify_ssl = {ssl}',f'name = "{name}"']) + "\n"
    
def load_pypi(repo_file):
    parse = None

    print(f'loading pypi server: {repo_file}', file=sys.stderr)

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
            print(f'{pkg} = {open_brace}version = "{release[pkg].version}", index = "{release[pkg].index}"{close_brace}')

    if build:
        print('[dev-packages]')

        for pkg in build:
            print(f'{pkg} = {open_brace}version = "{build[pkg].version}", index = "{build[pkg].index}"{close_brace}')

    if requires:
        print('[requires]')

        for pkg in requires:
            print(f'{pkg} = "{requires[pkg]}"')

def exec():
    for module in sys.argv[1:]:
        for repo_file in glob.glob(f'{module}/*.pypi'):
            print(f'adding pypi server: {repo_file}', file=sys.stderr)
            repos.append(load_pypi(repo_file))

        pipfile = f'{module}/Pipfile'

        if os.path.isfile(pipfile):
            print (f'processing: {pipfile}', file=sys.stderr)

            with open(pipfile) as file:
                parse = toml.load(file)

                update_release(pipfile, parse)
                update_build(pipfile, parse)
                update_requires(pipfile, parse)
        else:
            print(f'module spec: {module} does not have Pipfile - skipping', 
                  file=sys.stderr)

    print_pipfile()

if __name__ == '__main__':
    exec()
