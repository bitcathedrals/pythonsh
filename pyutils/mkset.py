import toml
from subprocess import Popen, PIPE

masked = {'virtualenv': True, 
          'setuptools': True,
          'pipenv': True,
          'pip': True}

def load_pipfile(masked):
    parse = toml.load('Pipfile')

    if 'dev-packages' in parse:
        for pkg in parse['dev-packages'].keys():
            masked[pkg] = True

def print_packages(masked):
    process = Popen(["pipenv","run","pip","freeze"],
                    text=True,
                    stdout=PIPE,
                    stderr=PIPE)

    output,error = process.communicate()
    exit_code = process.returncode

    if exit_code != 0:
        print(error)
        exit(1)

    for line in output.split('\n'):
        spec = line.split('==')
        
        if spec[0] in masked:
            continue

        print(spec[0])

def exec():
    load_pipfile(masked)
    print_packages(masked)

if __name__ == '__main__':
    exec()
