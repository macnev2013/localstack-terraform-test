from os import system, getcwd, chdir, chmod, listdir
from os.path import exists, realpath
from tempfile import NamedTemporaryFile


TF_REPO_NAME = 'terraform-provider-aws'
TF_REPO_PATH = f'{realpath(TF_REPO_NAME)}'

TF_REPO_PATCH_FILES = ['etc/001-hardcode-endpoint.patch']

TF_TEST_BINARY_FOLDER = 'test-bin'
TF_REPO_SERVICE_FOLDER = './internal/service'


def _get_test_bin_abs_path(service):
    return f'{TF_REPO_PATH}/{TF_TEST_BINARY_FOLDER}/{service}.test'


def execute_command(cmd, env=None, cwd=None):
    """
    Execute a command and return the return code.
    """
    _lwd = getcwd()
    if isinstance(cmd, list):
        cmd = ' '.join(cmd)
    else:
        raise Exception("Please provide command as list(str)")
    if cwd:
        chdir(cwd)
    if env:
        _env = ' '.join([f'{k}="{str(v)}"' for k, v in env.items()])
        cmd = f'{_env} {cmd}'
    log_file = NamedTemporaryFile()
    _err = system(f'{cmd} &> {log_file.name}')
    _log_file = open(log_file.name, 'r')
    _out = _log_file.read()
    _log_file.close()
    chdir(_lwd)
    return _err, _out


def build_test_bin(service, tf_root_path):
    _test_bin_abs_path = _get_test_bin_abs_path(service)
    _tf_repo_service_folder = f'{TF_REPO_SERVICE_FOLDER}/{service}'

    if exists(_test_bin_abs_path):
        return

    cmd = [
        "go",
        "test",
        "-c",
        _tf_repo_service_folder,
        "-o",
        _test_bin_abs_path,
    ]
    print(f'----> cmd: {cmd}')
    return_code, stdout = execute_command(cmd, cwd=tf_root_path)
    if return_code != 0:
        raise Exception(f"Error while building test binary for {service}")

    print(f"----> return_code: {return_code}")
    print(f"----> stdout: {stdout}")

    if exists(_test_bin_abs_path):
        chmod(_test_bin_abs_path, 0o755)

    return return_code, stdout


def get_all_services():
    services = []
    for service in listdir(f'{TF_REPO_PATH}/{TF_REPO_SERVICE_FOLDER}'):
        services.append(service)
    return sorted(services)


def patch_repo():
    print(f'Patching {TF_REPO_NAME}...')
    for patch_file in TF_REPO_PATCH_FILES:
        cmd = [
            'git',
            'apply',
            f'{realpath(patch_file)}',
        ]
        return_code, stdout = execute_command(cmd, cwd=realpath(TF_REPO_NAME))
        if return_code != 0:
            print("----- error while patching repo -----")
        if stdout:
            print(f'stdout: {stdout}')
