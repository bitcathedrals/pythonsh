import os
import sys
import glob
from pathlib import Path
import re
from collections import namedtuple
from subprocess import Popen, PIPE
from version_parser import Version

package_spec = namedtuple('package_spec', ['name','version', 'index'])

default_server = 'pypi'

import toml

pipdirs = []

pythonsh = {}

repos = []
release = {}
build = {}
requires = {}
global_section = {}

open_brace = "{"
close_brace = "}"

def load_pythonsh():
    with open('python.sh', 'r') as f:
        for line in f:
            stripped = line.strip()

            if line[0] == '#':
                continue

            if stripped == '':
                continue

            split = stripped.split('=')

            if len(split) == 2:
                pythonsh[split[0]] = split[1].replace('\'', '').replace('"', '')
            else:
                print(f'fpython.sh: line: "{line}" is malformed', file=sys.stderr)

def load_project():
    with open('project.toml', 'r') as f:
        data = toml.load(f)
    
        project = data['project']

        scripts = data['scripts']

        return {
            'project': project,
            'scripts': scripts
        }

def expand_version(version):
    if version == "*":
        return "9999999.0.0"

    fields = version.count('.')

    for i in range(fields + 1,3):
        version = version + '.0'

    return version

def get_python_version():
    if 'PYTHON_VERSION' in pythonsh:
        return pythonsh['PYTHON_VERSION']

    return None

def get_python_feature(spec):
    if not spec:
        return None
    
    v = spec.split('.')[0:2]

    return '.'.join(v)

def strip_pipfile_version_operators(spec):
     if spec == "*":
         return "*"
     
     return re.findall(r'\d+\.\d+\.\d+|\d+\.\d+', spec)[0]

def get_interpreter_version(spec):
    return expand_version(get_python_feature(spec)) 

def get_pipfile_version(spec):
    if spec == "*":
        return "*"
    
    feature=get_python_feature(strip_pipfile_version_operators(spec))

    return "~=" + feature + ".0"

def update_packages(filename, parse, section, table):
    
    for pkg_name in parse[section]:
        pkg_spec = parse[section][pkg_name]

        pkg_ver = None
        pkg_server = default_server

        if isinstance(pkg_spec, dict):
            pkg_ver = strip_pipfile_version_operators(pkg_spec['version'])
            pkg_server = pkg_spec['index']
        else:
            pkg_ver = strip_pipfile_version_operators(pkg_spec)

        if pkg_name in table:
            if table[pkg_name].version == '*' or pkg_ver == '*':
                pkg_ver = '*'
                print(f'package {pkg_name} version "*" overrides all other versions',
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

def update_requires(filename, parse):
    if 'requires' in parse and 'python_version' in parse['requires']:
        pythonsh_version = expand_version(get_python_version(parse['requires']['python_version']))

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
        ver = get_python_feature(pythonsh['PYTHON_VERSION'])

        if ver:
            parse['requires'] = {'python_version': ver}
        else:
            print('no python version found in requires section or python.sh: attempting to find latest.', 
                  file=sys.stderr)
            
            pyenv_list_command = 'pyenv install -l | sed -e \'s,^ *,,\' | grep -E \'^[0-9]+\.[0-9]+\.[0-9]+$\' | sort -u -V -r'

            process = Popen([pyenv_list_command],shell=True,
                            text=True,
                            stdout=PIPE)
            
            output = process.communicate()[0].decode()

            for line in output.split('\n'):
                if not line:
                    continue

                ver = get_python_feature(line.strip())
                break

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
    
def compile(*dirs):
    load_pythonsh()

    for module in dirs:
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
            version = get_pipfile_version(release[pkg].version)
            print(f'{pkg} = {open_brace}version = "{version}", index = "{release[pkg].index}"{close_brace}')

    if build:
        print('[dev-packages]')

        for pkg in build:
            version = get_pipfile_version(build[pkg].version)
            print(f'{pkg} = {open_brace}version = "{version}", index = "{build[pkg].index}"{close_brace}')

    if requires:
        print('[requires]')

        for pkg in requires:
            print(f'{pkg} = "{requires[pkg]}"')


def pyproject_deps(table):
    deps = []
    
    for pkg, spec in table.items():

        ver = spec.version

        if spec.index == 'pypi':
            if ver == '*':
                deps.append(f'"{pkg}"')
            else:
                deps.append(f'"{pkg} ~= {ver}"')
        else:
            print(f'skipping package: {pkg} from private repo {spec.index}')

    return "[" + ",".join(deps) + "]"

def print_pyproject():
    load_pythonsh()
    project = load_project()

    print('[build-system]')
    print('build-backend = "setuptools.build_meta"')

    print(f'requires = {pyproject_deps(build)}')

    if 'SOURCE' in pythonsh:
        print('[tool.setuptools.packages.find]')
        print(f'where = ["{pythonsh["SOURCE"]}"]')

    print('[tool.setuptools.package-data]')
    print(f'"*" = ["Pipfile", "*.pypi"]')
    
    print('[project]')
    
    if 'BUILD_NAME' in pythonsh:
        print(f'name = "{pythonsh["BUILD_NAME"]}"')
    
    if 'VERSION' in pythonsh:
        print(f'version = "{pythonsh["VERSION"]}"')

    if 'LICENSE' in pythonsh:
        print(f'license = "{project["LICENSE"]}')
    
    print(f'readme = "README.md"')

    if 'description' in project:
        print(f'description = \"{project["description"]}\"')
    
    if 'authors' in project:
        print(f'authors = "{project["authors"]}"')

    print(f'dependencies = {pyproject_deps(release)}')


    if 'homepage' in project or 'repository' in project:
        print('[project.urls]')
    
        if 'homepage' in project:
            print(f'homepage = "{project["homepage"]}"')
        if 'repository' in project:
            print(f'repository = "{project["repository"]}"')
    
    if 'scripts' in project:
        print('[project.scripts]')
        for name, path in project['scripts'].items():
            print(f'{name} = "{path}"')

def pipfile(pipdirs):
    compile(*pipdirs)
    
    print_pipfile()

def project(pipdirs):
    compile(*pipdirs)

    load_project()
    print_pyproject()

if __name__ == '__main__':
    pipdirs = sys.argv[2:]

    if sys.argv[1] == 'pipfile':
        pipfile(pipdirs)
        exit(0)

    if sys.argv[1] == 'project':
        project(pipdirs)
        exit(0)

    print('unknown command {sys.argv[1]}')
    exit(1)
    
