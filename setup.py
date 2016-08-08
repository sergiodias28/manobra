from setuptools import setup

setup(
    name='manobra',
    packages=['app'],
    include_package_data=True,
    install_requires=[
        'flask',
        'paramiko'
    ],
    setup_requires=[
        'pytest-runner',
    ],
    tests_require=[
        'pytest',
    ],
)
